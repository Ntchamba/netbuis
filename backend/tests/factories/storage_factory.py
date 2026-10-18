"""Fichiers de test déposés dans le stockage de TEST (dossiers temporaires de
config.settings.test : jamais backend/media ni backend/private_media)."""
from apps.business.services.storage_service import get_storage, new_key

# Plus petits fichiers dont les premiers octets sont reconnus par le contrôle de contenu.
JPEG_BYTES = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00" + b"x" * 20
PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"x" * 20
WEBP_BYTES = b"RIFF\x1a\x00\x00\x00WEBPVP8 " + b"x" * 20
MP4_BYTES = b"\x00\x00\x00\x18ftypisom\x00\x00\x02\x00" + b"x" * 20

SAMPLES = {
    "image/jpeg": JPEG_BYTES, "image/png": PNG_BYTES, "image/webp": WEBP_BYTES,
    "video/mp4": MP4_BYTES,
}


def make_stored_file(owner, kind="photo", content_type="image/jpeg") -> str:
    """Dépose un petit fichier valide pour `owner` et retourne sa clé de stockage."""
    storage = get_storage()
    key = new_key(owner.pk, kind, content_type)
    path = storage._path(key)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(SAMPLES[content_type])
    return key
