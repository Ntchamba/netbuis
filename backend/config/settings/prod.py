"""Réglages de PRODUCTION (T121). Aucun secret ici : tout vient de l'environnement.

Le démarrage est REFUSÉ (ImproperlyConfigured) si la configuration est dangereuse :
clé secrète courte ou de développement, hôtes ou origines absents, jokers (`*`), origines non
HTTPS. Le déploiement lui-même reste reporté (docs/deployment/DEPLOYMENT.md).
"""
from django.core.exceptions import ImproperlyConfigured

from .base import *  # noqa: F403
from .base import DEV_SECRET_KEY, env

DEBUG = False

# --- Secrets -------------------------------------------------------------------------------
MIN_KEY_LENGTH = 32  # octets : minimum de PyJWT pour HS256


def _check_key(name: str, value: str) -> None:
    if len(value.encode()) < MIN_KEY_LENGTH or value == DEV_SECRET_KEY or "dev-only" in value:
        raise ImproperlyConfigured(
            f"{name} doit être une valeur secrète d'au moins {MIN_KEY_LENGTH} caractères, "
            "différente de la clé de développement."
        )


_check_key("SECRET_KEY", SECRET_KEY)  # noqa: F405
_check_key("UPLOAD_SIGNING_KEY", UPLOAD_SIGNING_KEY)  # noqa: F405


# --- Hôtes et origines : listes explicites obligatoires, sans joker --------------------------
def _required_list(name: str) -> list[str]:
    values = env.list(name, default=[])
    if not values:
        raise ImproperlyConfigured(f"{name} est obligatoire en production.")
    if any("*" in value for value in values):
        raise ImproperlyConfigured(f"{name} : aucun joker « * » en production.")
    return values


def _required_https_origins(name: str) -> list[str]:
    values = _required_list(name)
    if any(not value.startswith("https://") for value in values):
        raise ImproperlyConfigured(f"{name} : origines en https:// seulement en production.")
    return values


ALLOWED_HOSTS = _required_list("ALLOWED_HOSTS")
CORS_ALLOWED_ORIGINS = _required_https_origins("CORS_ALLOWED_ORIGINS")
CSRF_TRUSTED_ORIGINS = _required_https_origins("CSRF_TRUSTED_ORIGINS")
CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOW_CREDENTIALS = True  # cookie de rafraîchissement du dashboard (D-01)

# --- HTTPS derrière un proxy (Railway, nginx…) --------------------------------------------------
# Le proxy termine TLS et pose X-Forwarded-Proto. Il DOIT écraser cet en-tête reçu du client.
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = env.bool("SECURE_SSL_REDIRECT", default=True)
# La sonde de santé du plateforme appelle souvent en HTTP simple, sans X-Forwarded-Proto :
# sans exemption elle recevrait une redirection et le service serait déclaré en panne.
SECURE_REDIRECT_EXEMPT = [r"^api/health/$"]

SECURE_HSTS_SECONDS = 31536000
# includeSubDomains et preload engagent TOUS les sous-domaines (et durablement, pour preload) :
# à activer volontairement, une fois le domaine définitif connu (voir DEPLOYMENT.md).
SECURE_HSTS_INCLUDE_SUBDOMAINS = env.bool("SECURE_HSTS_INCLUDE_SUBDOMAINS", default=False)
SECURE_HSTS_PRELOAD = env.bool("SECURE_HSTS_PRELOAD", default=False)

# --- Cookies et en-têtes ---------------------------------------------------------------------
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = "Lax"
CSRF_COOKIE_SECURE = True
CSRF_COOKIE_SAMESITE = "Lax"
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_REFERRER_POLICY = "same-origin"
SECURE_CROSS_ORIGIN_OPENER_POLICY = "same-origin"
X_FRAME_OPTIONS = "DENY"

# --- Surfaces d'administration et de documentation -------------------------------------------
# Schéma / documentation de l'API : fermés, sauf demande explicite.
API_DOCS_ENABLED = env.bool("API_DOCS_ENABLED", default=False)
# Admin Django : désactivé tant qu'un chemin non trivial n'est pas donné.
DJANGO_ADMIN_PATH = env("DJANGO_ADMIN_PATH", default="")
if DJANGO_ADMIN_PATH and (
    DJANGO_ADMIN_PATH.lstrip("/") in ("admin/", "django-admin/")
    or not DJANGO_ADMIN_PATH.endswith("/")
    or len(DJANGO_ADMIN_PATH) < 12
):
    raise ImproperlyConfigured(
        "DJANGO_ADMIN_PATH doit se terminer par « / », compter au moins 12 caractères et "
        "ne pas être « admin/ » ni « django-admin/ »."
    )
