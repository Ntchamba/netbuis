from .base import *  # noqa: F403

PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]
EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
SMS_PROVIDER = "console"
PAYMENT_PROVIDER = "fake"

# Les tests n'écrivent JAMAIS dans backend/media ni backend/private_media : dossiers
# temporaires, supprimés à la fin du processus (T027).
import atexit  # noqa: E402
import shutil  # noqa: E402
import tempfile  # noqa: E402
from pathlib import Path  # noqa: E402

_STORAGE_TMP = Path(tempfile.mkdtemp(prefix="netbuis-test-storage-"))
atexit.register(shutil.rmtree, _STORAGE_TMP, ignore_errors=True)
MEDIA_ROOT = _STORAGE_TMP / "media"
PRIVATE_MEDIA_ROOT = _STORAGE_TMP / "private_media"

# Le schéma de l'API est servi en test (comme en développement).
API_DOCS_ENABLED = True
