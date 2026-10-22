"""Réglages communs. Les secrets viennent UNIQUEMENT de l'environnement."""
from datetime import timedelta
from pathlib import Path

import environ

BASE_DIR = Path(__file__).resolve().parent.parent.parent

env = environ.Env(DEBUG=(bool, False), CREDITS_ENABLED=(bool, False))
environ.Env.read_env(BASE_DIR / ".env")  # absent = ignoré

# Clé de développement : 36 caractères (PyJWT exige au moins 32 octets pour HS256). Refusée en
# production (config/settings/prod.py).
DEV_SECRET_KEY = "dev-only-insecure-key-change-me-0000"
SECRET_KEY = env("SECRET_KEY", default=DEV_SECRET_KEY)
DEBUG = env("DEBUG")
ALLOWED_HOSTS = env.list("ALLOWED_HOSTS", default=["localhost", "127.0.0.1"])

DJANGO_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.postgres",
]
THIRD_PARTY_APPS = [
    "rest_framework",
    # Liste des jetons de rafraîchissement émis / invalidés (déconnexion, rotation) : T007.
    "rest_framework_simplejwt.token_blacklist",
    "drf_spectacular",
    "corsheaders",
]
LOCAL_APPS = [
    "apps.core",
    "apps.accounts",
    "apps.geo",
    "apps.catalog",
    "apps.business",
    "apps.search",
    "apps.calls",
    "apps.forum",
    "apps.trends",
    "apps.payments",
    "apps.admin_panel",
    "apps.notifications",
    "apps.printing",
]
INSTALLED_APPS = DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ]
        },
    }
]

# Pas de valeur par défaut : sans DATABASE_URL (backend/.env ou environnement),
# Django s'arrête avec « Set the DATABASE_URL environment variable ».
DATABASES = {"default": env.db("DATABASE_URL")}

AUTH_USER_MODEL = "accounts.User"
# Connexion par mot de passe (admin-login, admin Django) : seuls les comptes is_admin
# qui passent user.can_login() (ni bloqués, ni supprimés, ni inactifs).
AUTHENTICATION_BACKENDS = ["apps.accounts.backends.AdminOnlyBackend"]

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

LANGUAGE_CODE = "fr"
TIME_ZONE = "Africa/Douala"
USE_I18N = True
USE_TZ = True
LOCALE_PATHS = [BASE_DIR / "locale"]

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"  # espace PUBLIC (photos de commerce, publications)

# Stockage des fichiers envoyés (T027, D-17). "local" = dossiers du serveur, pour le
# développement ; un stockage compatible S3 viendra plus tard derrière la même interface
# (apps.business.services.storage_service.StorageService).
STORAGE_BACKEND = env("STORAGE_BACKEND", default="local")
# Espace PRIVÉ (CNI, diplôme) : HORS de MEDIA_ROOT, jamais servi par Django.
PRIVATE_MEDIA_ROOT = BASE_DIR / "private_media"
# Clé qui signe les jetons d'envoi et de téléchargement temporaire (sels dédiés dans le code).
# Par défaut SECRET_KEY ; une clé distincte peut être donnée par l'environnement.
UPLOAD_SIGNING_KEY = env("UPLOAD_SIGNING_KEY", default=SECRET_KEY)
UPLOAD_TOKEN_TTL = 15 * 60  # secondes : validité d'une URL d'envoi
PRIVATE_DOWNLOAD_TTL = 5 * 60  # secondes : validité d'une URL de lecture admin (CNI, diplôme)
# Début des URL temporaires de lecture. La route qui les sert est réservée à l'administration
# (T071) ; rien ne les sert avant.
PRIVATE_DOWNLOAD_URL_PREFIX = "/api/admin/private-files/"

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    # Sécurisé par défaut : les routes publiques doivent le déclarer explicitement
    # (AllowAny). Un compte bloqué ou supprimé est refusé même avec un jeton d'accès
    # encore valable (T008).
    "DEFAULT_PERMISSION_CLASSES": ("apps.accounts.permissions.IsAuthenticatedNotBlocked",),
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "DEFAULT_PAGINATION_CLASS": "apps.core.pagination.StandardPagination",
    "PAGE_SIZE": 20,
    "EXCEPTION_HANDLER": "apps.core.exceptions.api_exception_handler",
    # Taux des limites nommées (apps.core.throttling). Valeurs : BACKLOG T006 et D-05.
    "DEFAULT_THROTTLE_RATES": {
        "otp": "10/hour",  # demandes de code, par IP
        "otp_verify": "30/hour",  # vérifications de code, par IP (T006b)
        "call": "5/min",  # par compte
        "uploads": "60/hour",  # demandes d'URL d'envoi de fichier (T027), par compte
        "search": "60/min",  # recherches (écrite et vocale), par compte (T121)
        "suggest": "120/min",  # suggestions de saisie, par compte (T121)
    },
    # IP du client = REMOTE_ADDR : l'en-tête X-Forwarded-For (falsifiable) est ignoré tant que
    # NUM_PROXIES vaut 0. Derrière un proxy (Railway : 1), mettre NUM_PROXIES=1 dans
    # l'environnement, sinon tous les clients partagent l'IP du proxy (voir DEPLOYMENT.md).
    "NUM_PROXIES": env.int("NUM_PROXIES", default=0),
}

# Durées : BACKLOG T007 (accès 15 min, rafraîchissement 30 jours).
# Rotation et invalidation du jeton de rafraîchissement : apps.accounts.services.token_service.
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=15),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=30),
}
# Jeton de rafraîchissement du dashboard (D-01) : cookie HttpOnly, SameSite=Lax,
# Secure dès que DEBUG=False, envoyé seulement aux routes /api/auth/.
REFRESH_COOKIE_NAME = "netbuis_refresh"
REFRESH_COOKIE_PATH = "/api/auth/"

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "filters": {"personal_data": {"()": "apps.core.log_filters.PersonalDataFilter"}},
    "handlers": {
        "console": {"class": "logging.StreamHandler", "filters": ["personal_data"]},
    },
    "root": {"handlers": ["console"], "level": "INFO"},
}

# Schéma et documentation interactive de l'API (/api/schema/, /api/docs/) : servis seulement en
# développement. Désactivés par défaut en production (T121).
API_DOCS_ENABLED = env.bool("API_DOCS_ENABLED", default=DEBUG)
# Chemin de l'admin Django. Par défaut « django-admin/ » ; en production il est désactivé tant
# qu'un chemin non trivial n'est pas donné par l'environnement (config/settings/prod.py).
DJANGO_ADMIN_PATH = env("DJANGO_ADMIN_PATH", default="django-admin/")

SPECTACULAR_SETTINGS = {
    "TITLE": "NetBuis API",
    "DESCRIPTION": "Contrat d'API NetBuis (source de vérité : docs/api/openapi.yaml)",
    "VERSION": "0.1.0",
}

CORS_ALLOWED_ORIGINS = env.list("CORS_ALLOWED_ORIGINS", default=["http://localhost:5173"])
# Le dashboard envoie le cookie de rafraîchissement (D-01) : requêtes avec identifiants.
CORS_ALLOW_CREDENTIALS = True
CSRF_TRUSTED_ORIGINS = env.list("CSRF_TRUSTED_ORIGINS", default=["http://localhost:5173"])

# --- Fonctions activables ---
SMS_PROVIDER = env("SMS_PROVIDER", default="console")
CREDITS_ENABLED = env("CREDITS_ENABLED")
PAYMENT_PROVIDER = env("PAYMENT_PROVIDER", default="fake")  # fake | campay

# --- CamPay (vide jusqu'à É6 ; valeurs UNIQUEMENT via l'environnement) ---
CAMPAY_ENV = env("CAMPAY_ENV", default="DEV")  # DEV | PROD
CAMPAY_APP_USERNAME = env("CAMPAY_APP_USERNAME", default="")
CAMPAY_APP_PASSWORD = env("CAMPAY_APP_PASSWORD", default="")
CAMPAY_WEBHOOK_KEY = env("CAMPAY_WEBHOOK_KEY", default="")
