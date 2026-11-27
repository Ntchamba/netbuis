"""T121 — réglages de production : lus dans un processus à part avec des variables d'essai.

Aucune valeur réelle : les clés ci-dessous sont fabriquées par le test lui-même (aléatoires,
jamais écrites dans un fichier). Un processus neuf est nécessaire : les réglages sont lus à
l'import et le processus de test utilise `config.settings.test`.
"""
import json
import os
import secrets
import subprocess
import sys
from pathlib import Path

import pytest

BACKEND = Path(__file__).resolve().parent.parent
READ = (
    "import json, django\n"
    "from django.conf import settings as s\n"
    "print(json.dumps({k: getattr(s, k) for k in KEYS}))\n"
)
KEYS = [
    "DEBUG", "SECRET_KEY", "ALLOWED_HOSTS", "CORS_ALLOWED_ORIGINS", "CSRF_TRUSTED_ORIGINS",
    "CORS_ALLOW_ALL_ORIGINS", "CORS_ALLOW_CREDENTIALS", "SECURE_SSL_REDIRECT",
    "SECURE_PROXY_SSL_HEADER", "SECURE_HSTS_SECONDS", "SECURE_HSTS_INCLUDE_SUBDOMAINS",
    "SECURE_HSTS_PRELOAD", "SESSION_COOKIE_SECURE", "CSRF_COOKIE_SECURE",
    "SESSION_COOKIE_HTTPONLY", "SECURE_CONTENT_TYPE_NOSNIFF", "SECURE_REFERRER_POLICY",
    "X_FRAME_OPTIONS", "API_DOCS_ENABLED", "DJANGO_ADMIN_PATH", "SECURE_REDIRECT_EXEMPT",
    "UPLOAD_SIGNING_KEY", "SECURE_CROSS_ORIGIN_OPENER_POLICY",
]


def good_env(**override) -> dict:
    env = {
        "PATH": os.environ.get("PATH", ""),
        "DJANGO_SETTINGS_MODULE": "config.settings.prod",
        "DATABASE_URL": "postgres://u:x@localhost:5432/essai",
        "SECRET_KEY": secrets.token_urlsafe(48),
        "ALLOWED_HOSTS": "api.exemple.test",
        "CORS_ALLOWED_ORIGINS": "https://tableau.exemple.test",
        "CSRF_TRUSTED_ORIGINS": "https://tableau.exemple.test",
        # Variables facultatives : vides = valeur par défaut de la production.
        "DEBUG": "True",  # un DEBUG=True de l'environnement ne doit PAS passer en production
        "UPLOAD_SIGNING_KEY": "",
        "API_DOCS_ENABLED": "",
        "DJANGO_ADMIN_PATH": "",
        "SECURE_HSTS_INCLUDE_SUBDOMAINS": "",
        "SECURE_HSTS_PRELOAD": "",
        "SECURE_SSL_REDIRECT": "",
    }
    env.update(override)
    # django-environ traite une variable vide comme une valeur vide : on retire plutôt les vides
    # qui doivent retrouver leur défaut.
    return {k: v for k, v in env.items() if v != "" or k in override_empty(override)}


def override_empty(override) -> set:
    return {k for k, v in override.items() if v == ""}


def run(code: str, env: dict):
    return subprocess.run(
        [sys.executable, "-c", code], cwd=BACKEND, env=env, capture_output=True, text=True,
        timeout=120,
    )


def prod_settings(**override) -> dict:
    done = run(
        f"import django\nKEYS = {KEYS!r}\ndjango.setup()\n" + READ, good_env(**override)
    )
    assert done.returncode == 0, done.stderr[-800:]
    return json.loads(done.stdout.strip().splitlines()[-1])


# --- Valeurs de production ---------------------------------------------------------------


def test_valeurs_de_production():
    values = prod_settings()
    assert values["DEBUG"] is False  # même avec DEBUG=True dans l'environnement
    assert values["SECURE_SSL_REDIRECT"] is True
    assert values["SECURE_PROXY_SSL_HEADER"] == ["HTTP_X_FORWARDED_PROTO", "https"]
    assert values["SECURE_HSTS_SECONDS"] >= 31536000
    assert values["SESSION_COOKIE_SECURE"] and values["CSRF_COOKIE_SECURE"]
    assert values["SESSION_COOKIE_HTTPONLY"] is True
    assert values["SECURE_CONTENT_TYPE_NOSNIFF"] is True
    assert values["SECURE_REFERRER_POLICY"] == "same-origin"
    assert values["SECURE_CROSS_ORIGIN_OPENER_POLICY"] == "same-origin"
    assert values["X_FRAME_OPTIONS"] == "DENY"
    assert values["ALLOWED_HOSTS"] == ["api.exemple.test"]
    assert values["CORS_ALLOW_ALL_ORIGINS"] is False
    assert values["CORS_ALLOWED_ORIGINS"] == ["https://tableau.exemple.test"]
    assert values["CSRF_TRUSTED_ORIGINS"] == ["https://tableau.exemple.test"]
    assert values["CORS_ALLOW_CREDENTIALS"] is True  # cookie de rafraîchissement (D-01)
    assert len(values["SECRET_KEY"]) >= 32 and len(values["UPLOAD_SIGNING_KEY"]) >= 32
    # La sonde de santé est dispensée de la redirection HTTPS (plateforme derrière un proxy).
    assert values["SECURE_REDIRECT_EXEMPT"] == [r"^api/health/$"]
    # Surfaces fermées par défaut.
    assert values["API_DOCS_ENABLED"] is False
    assert values["DJANGO_ADMIN_PATH"] == ""
    # Engagements durables : pas activés sans décision.
    assert values["SECURE_HSTS_INCLUDE_SUBDOMAINS"] is False
    assert values["SECURE_HSTS_PRELOAD"] is False


def test_la_cle_de_signature_peut_etre_distincte():
    other = secrets.token_urlsafe(48)
    assert prod_settings(UPLOAD_SIGNING_KEY=other)["UPLOAD_SIGNING_KEY"] == other


# --- Démarrage refusé ----------------------------------------------------------------------


@pytest.mark.parametrize(
    "override, message",
    [
        ({"SECRET_KEY": "x" * 31}, "SECRET_KEY"),  # 31 caractères : trop court
        ({"SECRET_KEY": "dev-only-insecure-key-change-me-0000"}, "SECRET_KEY"),  # clé de dev
        ({"SECRET_KEY": "dev-only-" + "a" * 40}, "SECRET_KEY"),
        ({"UPLOAD_SIGNING_KEY": "court"}, "UPLOAD_SIGNING_KEY"),
        ({"ALLOWED_HOSTS": ""}, "ALLOWED_HOSTS"),
        ({"ALLOWED_HOSTS": "*"}, "ALLOWED_HOSTS"),
        ({"ALLOWED_HOSTS": "api.exemple.test,.exemple.*"}, "ALLOWED_HOSTS"),
        ({"CORS_ALLOWED_ORIGINS": ""}, "CORS_ALLOWED_ORIGINS"),
        ({"CORS_ALLOWED_ORIGINS": "http://tableau.exemple.test"}, "CORS_ALLOWED_ORIGINS"),
        ({"CORS_ALLOWED_ORIGINS": "https://*.exemple.test"}, "CORS_ALLOWED_ORIGINS"),
        ({"CSRF_TRUSTED_ORIGINS": ""}, "CSRF_TRUSTED_ORIGINS"),
        ({"CSRF_TRUSTED_ORIGINS": "http://localhost:5173"}, "CSRF_TRUSTED_ORIGINS"),
        ({"DJANGO_ADMIN_PATH": "django-admin/"}, "DJANGO_ADMIN_PATH"),
        ({"DJANGO_ADMIN_PATH": "court/"}, "DJANGO_ADMIN_PATH"),
        ({"DJANGO_ADMIN_PATH": "sans-barre-finale-longue"}, "DJANGO_ADMIN_PATH"),
    ],
)
def test_demarrage_refuse_si_la_configuration_est_dangereuse(override, message):
    done = run("import django; django.setup()", good_env(**override))
    assert done.returncode != 0
    assert "ImproperlyConfigured" in done.stderr and message in done.stderr


def test_la_cle_de_32_caracteres_est_acceptee():
    assert prod_settings(SECRET_KEY="k" * 32)["SECRET_KEY"] == "k" * 32


def test_la_cle_de_developpement_par_defaut_fait_32_octets_au_moins():
    from config.settings.base import DEV_SECRET_KEY

    assert len(DEV_SECRET_KEY.encode()) >= 32


# --- manage.py check --deploy --------------------------------------------------------------


def check_deploy(**override):
    return run(
        "import sys; from django.core.management import execute_from_command_line as m;"
        "m(['manage.py', 'check', '--deploy'])",
        good_env(**override),
    )


def test_check_deploy_ne_laisse_que_deux_avertissements_volontaires():
    done = check_deploy()
    output = done.stdout + done.stderr
    assert done.returncode == 0, output
    # HSTS includeSubDomains / preload : engagements à décider avec le domaine définitif.
    assert "security.W005" in output and "security.W021" in output
    for fixed in ("W001", "W002", "W003", "W004", "W006", "W007", "W008", "W009", "W012",
                  "W016", "W018", "W019", "W020", "W022"):
        assert f"security.{fixed}" not in output


def test_check_deploy_sans_aucun_avertissement_avec_les_options_activees():
    done = check_deploy(
        SECURE_HSTS_INCLUDE_SUBDOMAINS="True", SECURE_HSTS_PRELOAD="True",
        SECRET_KEY=secrets.token_urlsafe(64),
    )
    output = done.stdout + done.stderr
    assert done.returncode == 0 and "no issues" in output, output


# --- Routes fermées en production ------------------------------------------------------------


def resolves(path: str, **override) -> bool:
    code = (
        "import django; django.setup()\n"
        "from django.urls import resolve, Resolver404\n"
        f"try:\n    resolve({path!r}); print('OUI')\nexcept Resolver404:\n    print('NON')\n"
    )
    done = run(code, good_env(**override))
    assert done.returncode == 0, done.stderr[-600:]
    return done.stdout.strip().splitlines()[-1] == "OUI"


@pytest.mark.parametrize("path", ["/api/schema/", "/api/docs/"])
def test_schema_et_documentation_fermes_en_production(path):
    assert resolves(path) is False
    assert resolves(path, API_DOCS_ENABLED="True") is True  # ouverture volontaire possible


def test_admin_django_ferme_ou_a_un_chemin_non_trivial_en_production():
    assert resolves("/django-admin/") is False
    assert resolves("/admin/") is False
    chemin = "gestion-" + secrets.token_hex(6) + "/"
    assert resolves("/" + chemin, DJANGO_ADMIN_PATH=chemin) is True
    assert resolves("/django-admin/", DJANGO_ADMIN_PATH=chemin) is False


def test_la_sonde_de_sante_correspond_a_l_exemption_de_redirection():
    import re

    from django.urls import reverse

    values = prod_settings()
    assert re.match(values["SECURE_REDIRECT_EXEMPT"][0], reverse("health").lstrip("/"))


# --- Réglages de développement / test (contrôle négatif) -------------------------------------


def test_les_reglages_de_test_ne_sont_pas_ceux_de_production(settings):
    # Ce test échouerait si prod.py était importé par erreur dans les tests.
    assert settings.SECURE_SSL_REDIRECT is False
    assert settings.API_DOCS_ENABLED is True


def test_aucun_joker_dans_les_origines_de_base_ni_de_dev():
    from config.settings import base

    assert "*" not in base.ALLOWED_HOSTS
    assert all("*" not in o for o in base.CORS_ALLOWED_ORIGINS + base.CSRF_TRUSTED_ORIGINS)
