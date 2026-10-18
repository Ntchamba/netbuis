"""Envoi des photos et pièces d'identité (T027) : signature, réception, espace privé,
contrôle de propriété. Les fichiers vont dans les dossiers temporaires de config.settings.test."""
import logging
import time
from pathlib import Path

import pytest
from django.conf import settings
from django.core import signing
from django.core.cache import cache
from django.test import override_settings
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.business.services import storage_service
from apps.business.services.storage_service import (
    IMAGE_MAX_SIZE,
    VIDEO_MAX_SIZE,
    InvalidKey,
    InvalidToken,
    PrivateKey,
    PublicKey,
    get_storage,
    parse_key,
)
from apps.business.views import uploads_sign
from tests.factories.business_factory import make_owner
from tests.factories.storage_factory import (
    JPEG_BYTES,
    MP4_BYTES,
    PNG_BYTES,
    WEBP_BYTES,
    make_stored_file,
)

pytestmark = pytest.mark.django_db

SIGN = "/api/uploads/sign/"
ME = "/api/business/me/"
HTML = b"<html><script>alert(1)</script></html>" + b" " * 20
SVG = b'<?xml version="1.0"?><svg xmlns="http://www.w3.org/2000/svg"/>' + b" " * 20
GIF = b"GIF89a" + b"\x00" * 30
SMALL = len(JPEG_BYTES)
PRIVATE_KINDS = ["cni_photo", "diplome_photo"]
PUBLIC_KINDS = ["photo", "representant_photo", "post_image"]


@pytest.fixture(autouse=True)
def _clear_cache():
    cache.clear()
    yield
    cache.clear()


def connected(user):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    return client


@pytest.fixture(autouse=True)
def _isolated_storage(tmp_path):
    """Chaque test a ses propres dossiers (sous le répertoire temporaire du test)."""
    with override_settings(MEDIA_ROOT=tmp_path / "media",
                           PRIVATE_MEDIA_ROOT=tmp_path / "private_media"):
        yield


@pytest.fixture
def owner():
    return make_owner()


@pytest.fixture
def client(owner):
    return connected(owner)


def sign(client, kind="photo", content_type="image/jpeg", size=SMALL, **extra):
    return client.post(
        SIGN, {"kind": kind, "content_type": content_type, "size": size, **extra}, format="json"
    )


def put(ticket, data, content_type=None, client=None):
    return (client or APIClient()).put(
        ticket["upload_url"], data=data,
        content_type=content_type or ticket["headers"]["Content-Type"],
    )


def send(client, kind="photo", content_type="image/jpeg", data=JPEG_BYTES):
    """Signature puis envoi réussi ; retourne le ticket."""
    response = sign(client, kind, content_type, len(data))
    assert response.status_code == 200, response.content
    ticket = response.json()
    assert put(ticket, data).status_code == 204
    return ticket


def error_code(response, status):
    assert response.status_code == status, response.content
    return response.json()["code"]


def files_under(root):
    return [p for p in Path(root).rglob("*") if p.is_file()]


# --- POST /api/uploads/sign/ : cas qui réussissent ---------------------------------------


@pytest.mark.parametrize("kind", PUBLIC_KINDS + PRIVATE_KINDS)
@pytest.mark.parametrize("content_type,ext", [
    ("image/jpeg", "jpg"), ("image/png", "png"), ("image/webp", "webp"),
])
def test_signature_des_images(client, owner, kind, content_type, ext):
    response = sign(client, kind, content_type, IMAGE_MAX_SIZE)  # 5 Mo exactement : accepté
    assert response.status_code == 200, response.content
    body = response.json()
    assert set(body) == {"key", "upload_url", "method", "headers", "expires_in"}
    assert body["method"] == "PUT"
    assert body["headers"] == {"Content-Type": content_type}
    assert body["expires_in"] == settings.UPLOAD_TOKEN_TTL == 900
    assert body["upload_url"].startswith("http://testserver/api/uploads/local/")
    parsed = parse_key(body["key"])
    assert (parsed.owner_id, parsed.kind, parsed.ext) == (owner.pk, kind, ext)
    assert body["key"].startswith(f"u{owner.pk}/{kind}/")


def test_signature_video_de_publication(client):
    body = sign(client, "post_video", "video/mp4", VIDEO_MAX_SIZE).json()  # 30 Mo : accepté
    assert body["key"].endswith(".mp4")


def test_les_cles_sont_uniques_et_ignorent_le_nom_du_client(client):
    first = sign(client, filename="../../evil.php", name="a.php", extension="php").json()
    second = sign(client).json()
    assert first["key"] != second["key"]
    assert first["key"].endswith(".jpg")
    assert "evil" not in first["key"] and "php" not in first["key"]


# --- POST /api/uploads/sign/ : refus -----------------------------------------------------


@pytest.mark.parametrize("kind", ["video", "", "PHOTO", "../photo", "photo/../x", "photo\\x",
                                  "u1/photo", "cni", "post"])
def test_kind_inconnu(client, kind):
    response = sign(client, kind)
    assert error_code(response, 400) == ("invalid_kind" if kind else "invalid")
    assert kind == "" or kind not in response.content.decode()


def test_kind_avec_octet_nul_refuse(client):
    assert sign(client, "photo\x00").status_code == 400
    assert sign(client, "photo", "image/jpeg\x00").status_code == 400


@pytest.mark.parametrize("kind", ["photo", "cni_photo", "diplome_photo", "post_image"])
@pytest.mark.parametrize("content_type", [
    "image/svg+xml", "image/gif", "text/html", "application/pdf", "application/octet-stream",
    "video/mp4", "image/JPEG", "image/jpeg; charset=utf-8", "image/jpg", "", "image/*",
])
def test_type_refuse_pour_une_image(client, kind, content_type):
    expected = "invalid" if content_type == "" else "invalid_type"
    assert error_code(sign(client, kind, content_type), 400) == expected


@pytest.mark.parametrize("content_type", ["image/jpeg", "video/webm", "video/quicktime",
                                          "video/x-msvideo", "image/gif"])
def test_type_refuse_pour_la_video(client, content_type):
    assert error_code(sign(client, "post_video", content_type), 400) == "invalid_type"


@pytest.mark.parametrize("kind,limit", [
    ("photo", IMAGE_MAX_SIZE), ("cni_photo", IMAGE_MAX_SIZE), ("post_image", IMAGE_MAX_SIZE),
])
def test_image_trop_grosse(client, kind, limit):
    assert limit == 5 * 1024 * 1024
    assert error_code(sign(client, kind, size=limit + 1), 400) == "too_large"


def test_video_trop_grosse(client):
    assert VIDEO_MAX_SIZE == 30 * 1024 * 1024
    assert error_code(sign(client, "post_video", "video/mp4", VIDEO_MAX_SIZE + 1), 400) == (
        "too_large"
    )
    # 30 Mo est permis pour la vidéo mais pas pour une image.
    assert error_code(sign(client, "photo", "image/jpeg", VIDEO_MAX_SIZE), 400) == "too_large"


@pytest.mark.parametrize("size", [0, -1, "abc", 1.5, None, True, [5], {"a": 1}, ""])
def test_taille_invalide(client, size):
    assert error_code(sign(client, size=size), 400) == "invalid"


def test_champ_manquant(client):
    assert client.post(SIGN, {"kind": "photo", "content_type": "image/jpeg"},
                       format="json").status_code == 400
    assert client.post(SIGN, {}, format="json").status_code == 400


def test_anonyme_refuse():
    assert sign(APIClient()).status_code == 401


@pytest.mark.parametrize("flag", ["is_blocked", "is_deleted"])
def test_compte_bloque_ou_supprime_refuse(flag):
    user = make_owner()
    client = connected(user)
    setattr(user, flag, True)
    user.save()
    assert sign(client).status_code == 403


def test_limitation_de_debit_par_compte(client, monkeypatch):
    monkeypatch.setitem(uploads_sign.UploadRateThrottle.THROTTLE_RATES, "uploads", "3/hour")
    assert [sign(client).status_code for _ in range(3)] == [200, 200, 200]
    blocked = sign(client)
    assert error_code(blocked, 429) == "throttled"
    # Un autre compte a son propre compteur.
    assert sign(connected(make_owner())).status_code == 200


def test_le_taux_uploads_est_configure():
    assert settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"]["uploads"] == "60/hour"


# --- PUT /api/uploads/local/<token>/ : envois qui réussissent ----------------------------


@pytest.mark.parametrize("kind,content_type,data", [
    ("photo", "image/jpeg", JPEG_BYTES),
    ("representant_photo", "image/png", PNG_BYTES),
    ("post_image", "image/webp", WEBP_BYTES),
    ("post_video", "video/mp4", MP4_BYTES),
])
def test_envoi_public_complet(client, owner, kind, content_type, data):
    ticket = send(client, kind, content_type, data)
    storage = get_storage()
    assert storage.exists(ticket["key"])
    stored = Path(settings.MEDIA_ROOT) / ticket["key"]
    assert stored.read_bytes() == data
    assert not (Path(settings.PRIVATE_MEDIA_ROOT) / ticket["key"]).exists()
    assert storage.public_url(ticket["key"]) == f"/media/{ticket['key']}"
    # Aucun fichier temporaire ne reste.
    assert [p.name for p in stored.parent.iterdir() if p.name.startswith(".envoi-")] == []


@pytest.mark.parametrize("kind", PRIVATE_KINDS)
def test_envoi_prive_complet_sans_url_publique(client, kind):
    ticket = send(client, kind)
    key = ticket["key"]
    storage = get_storage()
    assert storage.exists(key)
    assert (Path(settings.PRIVATE_MEDIA_ROOT) / key).read_bytes() == JPEG_BYTES
    assert not (Path(settings.MEDIA_ROOT) / key).exists()
    assert not any(kind in str(p) for p in files_under(settings.MEDIA_ROOT))
    with pytest.raises(PrivateKey):
        storage.public_url(key)


def test_le_put_n_exige_pas_de_jeton_d_acces(client):
    ticket = sign(client).json()
    assert put(ticket, JPEG_BYTES, client=APIClient()).status_code == 204  # client anonyme


def test_dossier_cree_et_ecriture_par_morceaux(owner):
    storage = get_storage()
    ticket = storage.create_upload("photo", owner.pk, "image/jpeg", 100)
    token = ticket.upload_url.rstrip("/").rsplit("/", 1)[1]
    chunks = iter([JPEG_BYTES[:3], JPEG_BYTES[3:], b"y" * (100 - len(JPEG_BYTES))])
    assert storage.save_upload(token, "image/jpeg", chunks) == ticket.key
    assert (Path(settings.MEDIA_ROOT) / ticket.key).stat().st_size == 100


# --- PUT : refus -------------------------------------------------------------------------


def test_type_different_de_celui_signe(client):
    ticket = sign(client).json()
    assert error_code(put(ticket, PNG_BYTES, "image/png"), 400) == "invalid_type"
    assert not get_storage().exists(ticket["key"])


@pytest.mark.parametrize("data", [PNG_BYTES, WEBP_BYTES, MP4_BYTES, HTML, SVG, GIF,
                                  b"MZ\x90\x00" + b"\x00" * 30, b"\xff\xd8" + b"x" * 30])
def test_octets_differents_du_type_annonce(client, data):
    ticket = sign(client, size=len(data)).json()
    body = put(ticket, data)
    assert error_code(body, 400) == "invalid_content"
    assert not get_storage().exists(ticket["key"])
    assert files_under(Path(settings.MEDIA_ROOT) / f"u{parse_key(ticket['key']).owner_id}") == []
    assert ticket["key"] not in body.content.decode()


@pytest.mark.parametrize("content_type,data", [
    ("image/png", JPEG_BYTES), ("image/webp", PNG_BYTES), ("image/jpeg", WEBP_BYTES),
])
def test_chaque_type_exige_ses_propres_octets(client, content_type, data):
    ticket = sign(client, "photo", content_type, len(data)).json()
    assert error_code(put(ticket, data), 400) == "invalid_content"


def test_mp4_deguise_en_video_refuse(client):
    for data in (HTML, JPEG_BYTES, b"\x00\x00\x00\x14ftypqt  " + b"\x00" * 20):
        ticket = sign(client, "post_video", "video/mp4", len(data)).json()
        assert error_code(put(ticket, data), 400) == "invalid_content"


def test_fichier_plus_gros_que_la_taille_signee(client):
    ticket = sign(client, size=len(JPEG_BYTES)).json()
    response = put(ticket, JPEG_BYTES + b"x")
    assert error_code(response, 413) == "too_large"
    assert not get_storage().exists(ticket["key"])
    assert files_under(settings.MEDIA_ROOT) == []


def test_fichier_plus_petit_que_la_taille_signee(client):
    ticket = sign(client, size=len(JPEG_BYTES) + 10).json()
    assert error_code(put(ticket, JPEG_BYTES), 400) == "invalid_content"
    assert not get_storage().exists(ticket["key"])


def test_corps_vide(client):
    ticket = sign(client).json()
    assert error_code(put(ticket, b""), 400) == "invalid_content"


def test_fichier_plus_gros_que_la_limite_du_kind(owner):
    # Jeton fabriqué à la main avec une taille hors limite : refusé même si la signature est juste.
    key = storage_service.new_key(owner.pk, "photo", "image/jpeg")
    token = forged_token(owner.pk, "photo", key, "image/jpeg", IMAGE_MAX_SIZE + 1)
    response = APIClient().put(f"/api/uploads/local/{token}/", data=JPEG_BYTES,
                               content_type="image/jpeg")
    assert error_code(response, 403) == "invalid_token"


def test_lecture_du_corps_bornee():
    class Endless:
        def __init__(self):
            self.served = 0

        def read(self, n):
            self.served += n
            return b"x" * n

    stream = Endless()
    total = sum(len(chunk) for chunk in uploads_sign._chunks(stream, 200_000))
    assert 200_000 < total <= 200_001  # dépasse d'un octet, puis s'arrête
    assert stream.served <= 200_001
    assert list(uploads_sign._chunks(None, 10)) == []


def test_ecriture_interrompue_ne_laisse_rien(owner):
    storage = get_storage()
    ticket = storage.create_upload("photo", owner.pk, "image/jpeg", 50)
    token = ticket.upload_url.rstrip("/").rsplit("/", 1)[1]

    def too_much():
        yield JPEG_BYTES
        yield b"x" * 100

    with pytest.raises(storage_service.TooLarge):
        storage.save_upload(token, "image/jpeg", too_much())
    assert files_under(settings.MEDIA_ROOT) == []


def test_content_length_annonce_trop_grand_refuse_sans_lire(client):
    ticket = sign(client).json()
    response = APIClient().generic(
        "PUT", ticket["upload_url"], data=b"", content_type="image/jpeg",
        CONTENT_LENGTH=str(IMAGE_MAX_SIZE + 5),
    )
    assert error_code(response, 413) == "too_large"


# --- PUT : jeton --------------------------------------------------------------------------


def forged_token(owner_id, kind, key, content_type, size, salt="netbuis.upload.v1"):
    return signing.dumps(
        {"o": owner_id, "k": kind, "key": key, "ct": content_type, "s": size},
        key=settings.UPLOAD_SIGNING_KEY, salt=salt, compress=False,
    )


def test_jeton_reutilise_refuse(client):
    ticket = send(client)
    second = put(ticket, JPEG_BYTES)
    assert error_code(second, 403) == "already_used"
    assert (Path(settings.MEDIA_ROOT) / ticket["key"]).read_bytes() == JPEG_BYTES  # intact


def test_jeton_falsifie(client):
    ticket = sign(client).json()
    token = ticket["upload_url"].rstrip("/").rsplit("/", 1)[1]
    bad = token[:-2] + ("AA" if not token.endswith("AA") else "BB")
    for url in (f"/api/uploads/local/{bad}/", "/api/uploads/local/n-importe-quoi/",
                f"/api/uploads/local/{token.split(':')[0]}/"):
        response = APIClient().put(url, data=JPEG_BYTES, content_type="image/jpeg")
        assert error_code(response, 403) == "invalid_token"
    assert not get_storage().exists(ticket["key"])


def test_jeton_signe_avec_une_autre_cle(owner):
    key = storage_service.new_key(owner.pk, "photo", "image/jpeg")
    token = signing.dumps(
        {"o": owner.pk, "k": "photo", "key": key, "ct": "image/jpeg", "s": 40},
        key="une-autre-cle-de-signature-32-octets-ou-plus", salt="netbuis.upload.v1",
        compress=False,
    )
    response = APIClient().put(f"/api/uploads/local/{token}/", data=JPEG_BYTES,
                               content_type="image/jpeg")
    assert error_code(response, 403) == "invalid_token"


def test_jeton_expire(client):
    ticket = sign(client).json()
    with override_settings(UPLOAD_TOKEN_TTL=-1):  # tout jeton est déjà trop vieux
        assert error_code(put(ticket, JPEG_BYTES), 403) == "invalid_token"
    assert not get_storage().exists(ticket["key"])


def test_jeton_d_un_autre_kind_ou_d_une_autre_cle(owner):
    other = make_owner()
    cases = [
        # kind du jeton ≠ kind de la clé
        (owner.pk, "cni_photo", storage_service.new_key(owner.pk, "photo", "image/jpeg"),
         "image/jpeg", 40),
        # clé d'un autre compte
        (owner.pk, "photo", storage_service.new_key(other.pk, "photo", "image/jpeg"),
         "image/jpeg", 40),
        # type signé ≠ extension de la clé
        (owner.pk, "photo", storage_service.new_key(owner.pk, "photo", "image/jpeg"),
         "image/png", 40),
        # clé hors format (traversée)
        (owner.pk, "photo", f"u{owner.pk}/photo/../../../etc/x.jpg", "image/jpeg", 40),
        (owner.pk, "photo", f"u{owner.pk}/photo/a\x00b.jpg", "image/jpeg", 40),
        # kind inconnu
        (owner.pk, "x", storage_service.new_key(owner.pk, "photo", "image/jpeg"),
         "image/jpeg", 40),
    ]
    for owner_id, kind, key, content_type, size in cases:
        token = forged_token(owner_id, kind, key, content_type, size)
        response = APIClient().put(f"/api/uploads/local/{token}/", data=JPEG_BYTES,
                                   content_type=content_type)
        assert error_code(response, 403) == "invalid_token"
    assert files_under(settings.MEDIA_ROOT) == []
    assert files_under(settings.PRIVATE_MEDIA_ROOT) == []


def test_jeton_de_lecture_inutilisable_pour_l_envoi(owner):
    key = make_stored_file(owner, "cni_photo")
    download = get_storage().private_download_url(key).rstrip("/").rsplit("/", 1)[1]
    response = APIClient().put(f"/api/uploads/local/{download}/", data=JPEG_BYTES,
                               content_type="image/jpeg")
    assert error_code(response, 403) == "invalid_token"


def test_compte_bloque_apres_la_signature(client, owner):
    ticket = sign(client).json()
    owner.is_blocked = True
    owner.save()
    assert error_code(put(ticket, JPEG_BYTES), 403) == "invalid_token"
    assert not get_storage().exists(ticket["key"])


def test_get_et_autres_methodes_sur_la_route_d_envoi(client):
    ticket = sign(client).json()
    url = ticket["upload_url"]
    assert client.get(url).status_code == 405
    assert APIClient().post(url, data=JPEG_BYTES, content_type="image/jpeg").status_code == 405


# --- Traversée de chemin -------------------------------------------------------------------


@pytest.mark.parametrize("key", [
    "../x.jpg", "u1/../../x.jpg", "/etc/passwd", "u1\\photo\\x.jpg", "u1/photo/x.jpg\x00",
    "u1/photo/" + "a" * 32 + ".php", "u1/photo/" + "a" * 32 + ".svg",
    "u1/photo/" + "a" * 31 + ".jpg",
    "u1/photo/" + "A" * 32 + ".jpg", "u1/inconnu/" + "a" * 32 + ".jpg",
    "u1/post_video/" + "a" * 32 + ".jpg", "u1/photo/" + "a" * 32 + ".jpg/", "", "u/photo/x.jpg",
    "u١/photo/" + "a" * 32 + ".jpg", 42, None,
])
def test_cles_hors_format_refusees(key):
    with pytest.raises(InvalidKey):
        parse_key(key)
    storage = get_storage()
    assert storage.exists(key) is False
    with pytest.raises(InvalidKey):
        storage.delete(key)
    with pytest.raises(InvalidKey):
        storage.public_url(key)
    with pytest.raises(InvalidKey):
        storage.private_download_url(key)


@pytest.mark.parametrize("kind", ["../photo", "photo/..", "photo\x00", "a/b", "post_video\\"])
def test_create_upload_refuse_un_kind_piege(owner, kind):
    with pytest.raises(InvalidKey):
        get_storage().create_upload(kind, owner.pk, "image/jpeg", 10)


def test_delete_ne_sort_jamais_du_dossier(owner, tmp_path):
    outside = Path(settings.MEDIA_ROOT).parent / "dehors.txt"
    outside.parent.mkdir(parents=True, exist_ok=True)
    outside.write_text("garder")
    with pytest.raises(InvalidKey):
        get_storage().delete("../dehors.txt")
    assert outside.read_text() == "garder"


# --- Espace privé et URL temporaire ---------------------------------------------------------


def test_espaces_distincts_et_hors_du_depot():
    media = Path(settings.MEDIA_ROOT).resolve()
    private = Path(settings.PRIVATE_MEDIA_ROOT).resolve()
    assert media not in private.parents and private not in media.parents and media != private
    # Les tests n'utilisent jamais les vrais dossiers du projet.
    for real in (settings.BASE_DIR / "media", settings.BASE_DIR / "private_media"):
        assert real.resolve() not in (media, private)
        assert real.resolve() not in media.parents and real.resolve() not in private.parents


def test_reglages_de_production_gardent_l_espace_prive_hors_de_media_root():
    from config.settings import base

    assert Path(base.PRIVATE_MEDIA_ROOT) == base.BASE_DIR / "private_media"
    assert Path(base.MEDIA_ROOT) not in Path(base.PRIVATE_MEDIA_ROOT).parents
    assert Path(base.PRIVATE_MEDIA_ROOT) not in Path(base.MEDIA_ROOT).parents


def test_public_url_refuse_une_cle_privee(owner):
    storage = get_storage()
    for kind in PRIVATE_KINDS:
        with pytest.raises(PrivateKey):
            storage.public_url(make_stored_file(owner, kind))
    assert storage.public_url(make_stored_file(owner, "photo")).startswith("/media/u")


def test_url_temporaire_reservee_aux_pieces_privees(owner):
    storage = get_storage()
    with pytest.raises(PublicKey):
        storage.private_download_url(make_stored_file(owner, "photo"))
    key = make_stored_file(owner, "diplome_photo")
    url = storage.private_download_url(key)
    assert url.startswith(settings.PRIVATE_DOWNLOAD_URL_PREFIX)
    assert key not in url  # la clé n'apparaît pas en clair
    token = url[len(settings.PRIVATE_DOWNLOAD_URL_PREFIX):].rstrip("/")
    with storage.open_private_download(token) as stream:
        assert stream.read() == JPEG_BYTES


def test_url_temporaire_expire(owner, monkeypatch):
    storage = get_storage()
    key = make_stored_file(owner, "cni_photo")
    url = storage.private_download_url(key, ttl=300)
    token = url[len(settings.PRIVATE_DOWNLOAD_URL_PREFIX):].rstrip("/")
    storage.open_private_download(token).close()  # valable maintenant
    later = time.time() + 301
    monkeypatch.setattr(storage_service.time, "time", lambda: later)
    with pytest.raises(InvalidToken):
        storage.open_private_download(token)


def test_url_temporaire_duree_par_defaut_courte(owner, monkeypatch):
    assert settings.PRIVATE_DOWNLOAD_TTL == 300
    storage = get_storage()
    token = storage.private_download_url(make_stored_file(owner, "cni_photo")).split("/")[-2]
    soon = time.time() + 299
    monkeypatch.setattr(storage_service.time, "time", lambda: soon)
    storage.open_private_download(token).close()


def test_url_temporaire_jeton_falsifie_ou_d_un_autre_usage(owner):
    storage = get_storage()
    key = make_stored_file(owner, "cni_photo")
    token = storage.private_download_url(key).split("/")[-2]
    for bad in (token[:-2] + "xx", "n-importe-quoi", "", token.split(":")[0]):
        with pytest.raises(InvalidToken):
            storage.open_private_download(bad)
    # Un jeton d'ENVOI (autre sel) ne sert pas à lire.
    upload = storage.create_upload("cni_photo", owner.pk, "image/jpeg", 40)
    upload_token = upload.upload_url.rstrip("/").rsplit("/", 1)[1]
    with pytest.raises(InvalidToken):
        storage.open_private_download(upload_token)
    # Un jeton de lecture pour une clé publique ou piégée n'ouvre rien.
    public = make_stored_file(owner, "photo")
    for bad_key in (public, "../../etc/passwd"):
        forged = signing.dumps(
            {"key": bad_key, "exp": int(time.time()) + 300},
            key=settings.UPLOAD_SIGNING_KEY, salt="netbuis.private-download.v1", compress=False,
        )
        with pytest.raises(InvalidToken):
            storage.open_private_download(forged)
    # Même sel mais sans durée : refusé.
    no_exp = signing.dumps({"key": key}, key=settings.UPLOAD_SIGNING_KEY,
                           salt="netbuis.private-download.v1", compress=False)
    with pytest.raises(InvalidToken):
        storage.open_private_download(no_exp)


def test_aucune_route_ne_sert_les_pieces_privees(client, owner):
    key = make_stored_file(owner, "cni_photo")
    token = get_storage().private_download_url(key).split("/")[-2]
    for url in (f"/media/{key}", f"/api/media/{key}", f"/api/admin/private-files/{token}/",
                f"/private_media/{key}"):
        assert client.get(url).status_code == 404


def test_stockage_inconnu_refuse():
    with override_settings(STORAGE_BACKEND="inconnu"), pytest.raises(RuntimeError):
        get_storage()


# --- Contrôle de propriété dans le profil ----------------------------------------------------


def profile_body(user, **extra):
    from tests.factories.business_factory import get_or_make_zone, get_sector

    return {
        "type_compte": "boutique", "name": "Boutique de démonstration",
        "zone": get_or_make_zone().pk, "secteur": get_sector().pk,
        "photo": make_stored_file(user, "photo"),
        "representant_nom": "Personne de démonstration",
        "representant_photo": make_stored_file(user, "representant_photo"),
        "phone_anchor": "+237677123456", **extra,
    }


def create(client, body):
    return client.post("/api/business/", body, format="json")


def test_cle_issue_de_l_envoi_acceptee_dans_le_profil(client, owner):
    photo = send(client, "photo")["key"]
    representant = send(client, "representant_photo", "image/png", PNG_BYTES)["key"]
    response = create(client, profile_body(owner, photo=photo, representant_photo=representant))
    assert response.status_code == 201, response.content
    assert response.json()["photo"] == photo


def test_prestataire_avec_cni_privee_envoyee(client, owner):
    from tests.factories.business_factory import get_service_category

    cni = send(client, "cni_photo")["key"]
    diplome = send(client, "diplome_photo", "image/webp", WEBP_BYTES)["key"]
    body = profile_body(owner, type_compte="prestataire_service", cni_photo=cni,
                        diplome_photo=diplome, categorie_service=get_service_category().pk)
    body.pop("secteur")
    response = create(client, body)
    assert response.status_code == 201, response.content
    assert "cni_photo" not in response.json()
    assert cni not in response.content.decode()
    assert response.json()["has_cni"] is True


def test_cle_d_un_autre_compte_refusee(client, owner):
    other = make_owner()
    for field, kind in (("photo", "photo"), ("representant_photo", "representant_photo")):
        stolen = make_stored_file(other, kind)
        response = create(client, profile_body(owner, **{field: stolen}))
        assert response.status_code == 400
        assert field in response.json()["fields"]
        assert stolen not in response.content.decode()


def test_prefixe_d_un_autre_compte_proche_refuse(client, owner):
    # u1 ne doit pas ouvrir u10 : le préfixe est comparé à l'identifiant entier exact.
    other = make_owner()
    key = make_stored_file(other, "photo")
    assert parse_key(key).owner_id != owner.pk
    assert "photo" in create(client, profile_body(owner, photo=key)).json()["fields"]


def test_cle_d_un_autre_kind_refusee(client, owner):
    for field, kind in (("photo", "representant_photo"), ("representant_photo", "photo"),
                        ("photo", "post_image"), ("photo", "cni_photo")):
        wrong = make_stored_file(owner, kind)
        response = create(client, profile_body(owner, **{field: wrong}))
        assert field in response.json()["fields"], (field, kind)
    from tests.factories.business_factory import get_service_category

    body = profile_body(owner, type_compte="prestataire_service",
                        categorie_service=get_service_category().pk)
    body.pop("secteur")
    for wrong_kind in ("diplome_photo", "photo"):
        body["cni_photo"] = make_stored_file(owner, wrong_kind)
        assert "cni_photo" in create(client, body).json()["fields"]
    body["cni_photo"] = make_stored_file(owner, "cni_photo")
    body["diplome_photo"] = make_stored_file(owner, "cni_photo")
    assert "diplome_photo" in create(client, body).json()["fields"]


def test_cle_inexistante_refusee(client, owner):
    ghost = storage_service.new_key(owner.pk, "photo", "image/jpeg")  # jamais envoyée
    response = create(client, profile_body(owner, photo=ghost))
    assert response.status_code == 400
    assert "photo" in response.json()["fields"]
    assert ghost not in response.content.decode()


def test_cle_privee_posee_dans_l_espace_public_refusee(client, owner):
    from tests.factories.business_factory import get_service_category

    key = storage_service.new_key(owner.pk, "cni_photo", "image/jpeg")
    wrong_place = Path(settings.MEDIA_ROOT) / key  # PAS dans l'espace privé
    wrong_place.parent.mkdir(parents=True, exist_ok=True)
    wrong_place.write_bytes(JPEG_BYTES)
    body = profile_body(owner, type_compte="prestataire_service", cni_photo=key,
                        categorie_service=get_service_category().pk)
    body.pop("secteur")
    assert "cni_photo" in create(client, body).json()["fields"]


def test_ancienne_cle_libre_refusee(client, owner):
    for old in ("profils/photo.jpg", "prive/cni.jpg", f"u{owner.pk}/photo/x.jpg"):
        assert "photo" in create(client, profile_body(owner, photo=old)).json()["fields"]


def test_patch_controle_aussi_la_propriete(client, owner):
    assert create(client, profile_body(owner)).status_code == 201
    other_key = make_stored_file(make_owner(), "photo")
    response = client.patch(ME, {"photo": other_key}, format="json")
    assert response.status_code == 400
    assert other_key not in response.content.decode()
    mine = make_stored_file(owner, "photo")
    assert client.patch(ME, {"photo": mine}, format="json").status_code == 200


def test_champ_vide_toujours_permis_pour_les_champs_facultatifs(client, owner):
    assert create(client, profile_body(owner, diplome_photo="")).status_code == 201


# --- Journaux et réponses -------------------------------------------------------------------


def test_aucun_journal_ne_contient_cle_ni_contenu(client, caplog):
    caplog.set_level(logging.DEBUG)
    secret = b"\xff\xd8\xff\xe0SECRET-CNI-CONTENT" + b"z" * 20
    ticket = send(client, "cni_photo", data=secret)
    put(ticket, HTML)  # rejeu refusé
    bad = sign(client, "cni_photo", size=len(HTML)).json()
    put(bad, HTML)  # contenu refusé
    assert ticket["key"] not in caplog.text
    assert bad["key"] not in caplog.text
    assert "SECRET-CNI-CONTENT" not in caplog.text
    assert "script" not in caplog.text


def test_les_reponses_d_erreur_ne_renvoient_ni_contenu_ni_cle(client):
    ticket = sign(client, "cni_photo", size=len(HTML)).json()
    response = put(ticket, HTML)
    text = response.content.decode()
    assert ticket["key"] not in text
    assert "script" not in text
    assert set(response.json()) == {"code", "message"}
