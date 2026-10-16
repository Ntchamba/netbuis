"""Réglages communs. Les secrets viennent UNIQUEMENT de l'environnement."""
from datetime import timedelta
from pathlib import Path

import environ

BASE_DIR = Path(__file__).resolve().parent.parent.parent

env = environ.Env(DEBUG=(bool, False), CREDITS_ENABLED=(bool, False))
environ.Env.read_env(BASE_DIR / ".env")  # absent = ignoré

SECRET_KEY = env("SECRET_KEY", default="dev-only-insecure-key-change-me")
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

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

LANGUAGE_CODE = "fr"
TIME_ZONE = "Africa/Douala"
USE_I18N = True
USE_TZ = True
LOCALE_PATHS = [BASE_DIR / "locale"]

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    # Sécurisé par défaut : les routes publiques doivent le déclarer explicitement.
    "DEFAULT_PERMISSION_CLASSES": ("rest_framework.permissions.IsAuthenticated",),
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "DEFAULT_PAGINATION_CLASS": "apps.core.pagination.StandardPagination",
    "PAGE_SIZE": 20,
    "EXCEPTION_HANDLER": "apps.core.exceptions.api_exception_handler",
    # Taux des limites nommées (apps.core.throttling). Valeurs : BACKLOG T006 et D-05.
    "DEFAULT_THROTTLE_RATES": {
        "otp": "10/hour",  # demandes de code, par IP
        "otp_verify": "30/hour",  # vérifications de code, par IP (T006b)
        "call": "5/min",  # par compte
    },
    # IP du client = REMOTE_ADDR : l'en-tête X-Forwarded-For (falsifiable) est ignoré.
    # À régler au déploiement derrière un proxy (nombre de proxys de confiance).
    "NUM_PROXIES": 0,
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=30),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=30),
}

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "filters": {"personal_data": {"()": "apps.core.log_filters.PersonalDataFilter"}},
    "handlers": {
        "console": {"class": "logging.StreamHandler", "filters": ["personal_data"]},
    },
    "root": {"handlers": ["console"], "level": "INFO"},
}

SPECTACULAR_SETTINGS = {
    "TITLE": "NetBuis API",
    "DESCRIPTION": "Contrat d'API NetBuis (source de vérité : docs/api/openapi.yaml)",
    "VERSION": "0.1.0",
}

CORS_ALLOWED_ORIGINS = env.list("CORS_ALLOWED_ORIGINS", default=["http://localhost:5173"])
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
