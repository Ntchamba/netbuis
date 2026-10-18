"""Stockage des fichiers envoyés (photos, pièces d'identité, médias de publication). T027, D-17.

ZONE SENSIBLE (relue ligne par ligne par Jeff).

Règles
- Les clés sont CRÉÉES PAR LE SERVEUR : `u<id du compte>/<kind>/<32 caractères hexadécimaux>.<ext>`.
  Ni le nom du fichier ni l'extension ne viennent du client : l'extension se déduit du type
  de contenu vérifié. Toute clé est relue avec `parse_key` (format strict) avant tout accès
  disque, donc aucune traversée de chemin (`..`, `/`, `\\`, octet nul) n'est possible.
- Deux espaces : PUBLIC (`MEDIA_ROOT` : photo, representant_photo, post_image, post_video) et
  PRIVÉ (`PRIVATE_MEDIA_ROOT`, hors de `MEDIA_ROOT` : cni_photo, diplome_photo). Une clé
  privée n'a AUCUNE URL publique ; l'administration reçoit une URL TEMPORAIRE signée.
- Envoi en deux temps : `create_upload` (contrôle du type et de la taille annoncés, retourne un
  jeton signé de courte durée) puis `save_upload` (réception : taille, type et octets réels
  vérifiés, écriture atomique, un seul envoi par jeton).

Extension S3 : écrire une sous-classe de `StorageService` (URL pré-signées de PUT pour
`create_upload`, URL pré-signées de GET pour `private_download_url`, deux seaux distincts dont
un privé), puis la brancher dans `get_storage()` avec `STORAGE_BACKEND`. Aucune implémentation
S3 n'existe pour l'instant.
"""
from __future__ import annotations

import contextlib
import os
import re
import tempfile
import time
import uuid
from abc import ABC, abstractmethod
from collections.abc import Iterable
from dataclasses import dataclass, field
from pathlib import Path
from typing import BinaryIO

from django.conf import settings
from django.core import signing
from django.urls import reverse

MB = 1024 * 1024
IMAGE_MAX_SIZE = 5 * MB  # 5 242 880 octets
VIDEO_MAX_SIZE = 30 * MB

JPEG, PNG, WEBP, MP4 = "image/jpeg", "image/png", "image/webp", "video/mp4"
_IMAGES = {JPEG: "jpg", PNG: "png", WEBP: "webp"}
_VIDEOS = {MP4: "mp4"}

# kind -> (types acceptés avec leur extension, taille maximale, espace privé ?)
KINDS: dict[str, tuple[dict[str, str], int, bool]] = {
    "photo": (_IMAGES, IMAGE_MAX_SIZE, False),
    "representant_photo": (_IMAGES, IMAGE_MAX_SIZE, False),
    "cni_photo": (_IMAGES, IMAGE_MAX_SIZE, True),
    "diplome_photo": (_IMAGES, IMAGE_MAX_SIZE, True),
    "post_image": (_IMAGES, IMAGE_MAX_SIZE, False),
    "post_video": (_VIDEOS, VIDEO_MAX_SIZE, False),
}
PRIVATE_KINDS = frozenset(kind for kind, (_, _, private) in KINDS.items() if private)

# Marques « ftyp » MP4 acceptées (ni QuickTime « qt  », ni 3GPP).
_MP4_BRANDS = frozenset(
    {b"isom", b"iso2", b"iso3", b"iso4", b"iso5", b"iso6", b"mp41", b"mp42", b"avc1", b"dash"}
)

_KEY_RE = re.compile(
    r"u(?P<owner>[0-9]{1,18})/(?P<kind>[a-z_]{1,30})/(?P<name>[0-9a-f]{32})\.(?P<ext>[a-z0-9]{2,4})"
)
_UPLOAD_SALT = "netbuis.upload.v1"
_DOWNLOAD_SALT = "netbuis.private-download.v1"
CHUNK_SIZE = 64 * 1024
_HEADER_LEN = 16  # octets lus au début du fichier pour reconnaître son format


class StorageError(Exception):
    """Erreur de stockage. `code` est stable ; le message n'a jamais de clé ni de contenu."""

    code = "storage_error"

    def __init__(self, message: str = "Erreur de stockage."):
        super().__init__(message)
        self.message = message


class InvalidKey(StorageError):
    code = "invalid_key"


class InvalidToken(StorageError):
    code = "invalid_token"


class AlreadyUploaded(StorageError):
    code = "already_used"


class InvalidContent(StorageError):
    code = "invalid_content"


class InvalidType(StorageError):
    code = "invalid_type"


class TooLarge(StorageError):
    code = "too_large"


class PrivateKey(StorageError):
    code = "private_key"


class PublicKey(StorageError):
    code = "public_key"


@dataclass(frozen=True)
class UploadTicket:
    key: str
    upload_url: str
    method: str = "PUT"
    headers: dict[str, str] = field(default_factory=dict)
    expires_in: int = 0


@dataclass(frozen=True)
class ParsedKey:
    owner_id: int
    kind: str
    ext: str


def parse_key(key: object) -> ParsedKey:
    """Lit une clé de stockage ; lève `InvalidKey` si elle n'a pas EXACTEMENT le format serveur."""
    match = _KEY_RE.fullmatch(key) if isinstance(key, str) else None
    if match is None:
        raise InvalidKey("Clé de fichier invalide.")
    kind, ext = match["kind"], match["ext"]
    if kind not in KINDS or ext not in KINDS[kind][0].values():
        raise InvalidKey("Clé de fichier invalide.")
    return ParsedKey(owner_id=int(match["owner"]), kind=kind, ext=ext)


def is_private_kind(kind: str) -> bool:
    return kind in PRIVATE_KINDS


def allowed_types(kind: str) -> dict[str, str]:
    return KINDS[kind][0]


def max_size(kind: str) -> int:
    return KINDS[kind][1]


def detect_content_type(header: bytes) -> str | None:
    """Type réel d'après les premiers octets (JPEG, PNG, WebP, MP4), sinon None."""
    if header.startswith(b"\xff\xd8\xff"):
        return JPEG
    if header.startswith(b"\x89PNG\r\n\x1a\n"):
        return PNG
    if header[:4] == b"RIFF" and header[8:12] == b"WEBP":
        return WEBP
    if header[4:8] == b"ftyp" and header[8:12] in _MP4_BRANDS:
        return MP4
    return None


def new_key(owner_id: int, kind: str, content_type: str) -> str:
    """Clé aléatoire côté serveur ; l'extension vient du type VÉRIFIÉ, jamais du client."""
    types, _, _ = KINDS[kind]
    return f"u{int(owner_id)}/{kind}/{uuid.uuid4().hex}.{types[content_type]}"


class StorageService(ABC):
    """Interface commune : stockage local (dev) ou compatible S3 (plus tard)."""

    @abstractmethod
    def create_upload(self, kind: str, owner_id: int, content_type: str, size: int) -> UploadTicket:
        """Contrôle le type et la taille annoncés, réserve une clé et retourne l'envoi à faire."""

    @abstractmethod
    def save_upload(self, token: str, content_type: str, data: Iterable[bytes]) -> str:
        """Reçoit le fichier d'un envoi direct (stockage local) ; retourne la clé écrite."""

    @abstractmethod
    def exists(self, key: str) -> bool:
        """Vrai si le fichier existe dans l'espace qui correspond à son `kind`."""

    @abstractmethod
    def delete(self, key: str) -> None:
        """Supprime le fichier (sans erreur s'il n'existe pas)."""

    @abstractmethod
    def private_download_url(self, key: str, ttl: int | None = None) -> str:
        """URL TEMPORAIRE de lecture d'une pièce privée, pour l'administration seulement.
        Refuse une clé publique (`PublicKey`)."""

    @abstractmethod
    def public_url(self, key: str) -> str:
        """URL publique d'une image publique ; lève `PrivateKey` pour une pièce privée."""


class LocalStorageService(StorageService):
    """Dossiers du serveur : `MEDIA_ROOT` (public) et `PRIVATE_MEDIA_ROOT` (privé)."""

    # --- chemins ---------------------------------------------------------------------

    @staticmethod
    def _root(private: bool) -> Path:
        return Path(settings.PRIVATE_MEDIA_ROOT if private else settings.MEDIA_ROOT)

    def _path(self, key: str) -> Path:
        parsed = parse_key(key)
        root = self._root(is_private_kind(parsed.kind)).resolve()
        path = (root / key).resolve()
        if root not in path.parents:  # ceinture et bretelles : la clé est déjà stricte
            raise InvalidKey("Clé de fichier invalide.")
        return path

    # --- envoi -----------------------------------------------------------------------

    def create_upload(self, kind: str, owner_id: int, content_type: str, size: int) -> UploadTicket:
        if kind not in KINDS:
            raise InvalidKey("Type d'envoi inconnu.")
        types, limit, _ = KINDS[kind]
        if content_type not in types:
            raise InvalidType("Ce type de fichier n'est pas accepté.")
        if isinstance(size, bool) or not isinstance(size, int) or size < 1:
            raise StorageError("Taille invalide.")
        if size > limit:
            raise TooLarge("Le fichier est trop gros.")
        key = new_key(owner_id, kind, content_type)
        token = signing.dumps(
            {"o": int(owner_id), "k": kind, "key": key, "ct": content_type, "s": size},
            key=settings.UPLOAD_SIGNING_KEY, salt=_UPLOAD_SALT, compress=False,
        )
        url = reverse("business:upload-local", kwargs={"token": token})
        return UploadTicket(
            key=key, upload_url=url, method="PUT", headers={"Content-Type": content_type},
            expires_in=settings.UPLOAD_TOKEN_TTL,
        )

    def read_upload_token(self, token: str) -> dict:
        """Jeton d'envoi vérifié (signature, durée) ET cohérent ; sinon `InvalidToken`."""
        try:
            data = signing.loads(
                token, key=settings.UPLOAD_SIGNING_KEY, salt=_UPLOAD_SALT,
                max_age=settings.UPLOAD_TOKEN_TTL,
            )
            parsed = parse_key(data["key"])
            types, limit, _ = KINDS[data["k"]]
            owner, content_type, size = data["o"], data["ct"], data["s"]
            consistent = (
                parsed.kind == data["k"] and parsed.owner_id == owner
                and types.get(content_type) == parsed.ext
                and isinstance(size, int) and not isinstance(size, bool) and 1 <= size <= limit
            )
        except (signing.BadSignature, StorageError, KeyError, TypeError):
            raise InvalidToken("Lien d'envoi invalide ou expiré.") from None
        if not consistent:
            raise InvalidToken("Lien d'envoi invalide ou expiré.")
        return data

    def save_upload(self, token: str, content_type: str, data: Iterable[bytes]) -> str:
        claims = self.read_upload_token(token)
        if content_type != claims["ct"]:
            raise InvalidType("Le type du fichier ne correspond pas à celui annoncé.")
        key, size = claims["key"], claims["s"]
        destination = self._path(key)
        if destination.exists():
            raise AlreadyUploaded("Ce lien d'envoi a déjà servi.")
        destination.parent.mkdir(parents=True, exist_ok=True)
        # Fichier temporaire dans le même dossier (même disque) puis liaison atomique.
        handle, temp_name = tempfile.mkstemp(
            prefix=".envoi-", suffix=".tmp", dir=destination.parent
        )
        temp = Path(temp_name)
        try:
            with os.fdopen(handle, "wb") as out:
                self._copy_checked(data, out, claims["ct"], size)
            try:
                os.link(temp, destination)  # atomique, et refuse d'écraser un fichier existant
            except FileExistsError:
                raise AlreadyUploaded("Ce lien d'envoi a déjà servi.") from None
        finally:
            with contextlib.suppress(FileNotFoundError):
                temp.unlink()
        return key

    @staticmethod
    def _copy_checked(data: Iterable[bytes], out: BinaryIO, content_type: str, size: int) -> None:
        """Écrit en vérifiant la taille au fil de l'eau (jamais plus de `size` octets écrits)
        et le format d'après les premiers octets. Le contenu n'est jamais gardé en mémoire."""
        header = b""
        total = 0
        for chunk in data:
            total += len(chunk)
            if total > size:
                raise TooLarge("Le fichier est plus gros que prévu.")
            if len(header) < _HEADER_LEN:
                header += chunk[: _HEADER_LEN - len(header)]
                if len(header) >= _HEADER_LEN and detect_content_type(header) != content_type:
                    raise InvalidContent("Le contenu du fichier ne correspond pas à son type.")
            out.write(chunk)
        if total != size:
            raise InvalidContent("La taille du fichier ne correspond pas à celle annoncée.")
        if detect_content_type(header) != content_type:
            raise InvalidContent("Le contenu du fichier ne correspond pas à son type.")

    # --- lecture / suppression -----------------------------------------------------------

    def exists(self, key: str) -> bool:
        try:
            return self._path(key).is_file()
        except InvalidKey:
            return False

    def delete(self, key: str) -> None:
        with contextlib.suppress(FileNotFoundError):
            self._path(key).unlink()

    def public_url(self, key: str) -> str:
        if is_private_kind(parse_key(key).kind):
            raise PrivateKey("Cette pièce est privée : elle n'a pas d'adresse publique.")
        return f"{_media_prefix()}{key}"

    def private_download_url(self, key: str, ttl: int | None = None) -> str:
        if not is_private_kind(parse_key(key).kind):
            raise PublicKey("Seules les pièces privées ont une adresse temporaire.")
        lifetime = settings.PRIVATE_DOWNLOAD_TTL if ttl is None else ttl
        token = signing.dumps(
            {"key": key, "exp": int(time.time()) + int(lifetime)},
            key=settings.UPLOAD_SIGNING_KEY, salt=_DOWNLOAD_SALT, compress=False,
        )
        return f"{settings.PRIVATE_DOWNLOAD_URL_PREFIX}{token}/"

    def open_private_download(self, token: str) -> BinaryIO:
        """Pour la route admin (T071) : ouvre la pièce désignée par un jeton de lecture valide
        (signature juste, non expiré). Sinon `InvalidToken`, sans dire pourquoi."""
        try:
            data = signing.loads(token, key=settings.UPLOAD_SIGNING_KEY, salt=_DOWNLOAD_SALT)
            if int(data["exp"]) <= time.time():
                raise InvalidToken
            key = data["key"]
            if not is_private_kind(parse_key(key).kind):
                raise InvalidKey
            return self._path(key).open("rb")
        except (signing.BadSignature, StorageError, KeyError, TypeError, ValueError,
                FileNotFoundError):
            raise InvalidToken("Lien de lecture invalide ou expiré.") from None


def _media_prefix() -> str:
    prefix = settings.MEDIA_URL
    return prefix if prefix.startswith("/") else "/" + prefix


def get_storage() -> StorageService:
    """Fabrique selon `STORAGE_BACKEND`. Un stockage S3 se branchera ici."""
    if settings.STORAGE_BACKEND == "local":
        return LocalStorageService()
    raise RuntimeError("STORAGE_BACKEND inconnu.")
