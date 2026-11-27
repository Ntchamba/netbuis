"""Serveur ASGI et connexion PostgreSQL directe (T131 point 8)."""
import inspect
from pathlib import Path

import pytest
from django.db import connection
from psycopg.conninfo import conninfo_to_dict

from apps.calls.services.streams import listen_conninfo

ROOT = Path(__file__).resolve().parents[4]


def test_l_application_asgi_existe_et_est_asynchrone():
    from config.asgi import application

    assert inspect.iscoroutinefunction(application.__call__)


def test_le_serveur_asgi_est_dans_les_dependances_et_la_commande_est_documentee():
    requirements = (ROOT / "backend" / "requirements" / "base.txt").read_text(encoding="utf-8")
    assert "uvicorn==" in requirements
    doc = (ROOT / "docs" / "deployment" / "APPELS_ASGI.md").read_text(encoding="utf-8")
    for needle in ("uvicorn config.asgi:application", "LISTEN", "pgbouncer",
                   "CALLS_LISTEN_DATABASE_URL", "expire_calls", "JITSI_JWT_SECRET"):
        assert needle in doc, needle


@pytest.mark.django_db
def test_la_connexion_d_ecoute_vise_la_meme_base_que_l_application():
    info = conninfo_to_dict(listen_conninfo())
    assert info["dbname"] == connection.settings_dict["NAME"]
    assert info.get("host", "") == (connection.settings_dict["HOST"] or "")


def test_une_connexion_directe_distincte_peut_etre_donnee(settings):
    settings.CALLS_LISTEN_DATABASE_URL = "postgres://ecoute:x@direct.example.test:5432/maBase"
    info = conninfo_to_dict(listen_conninfo())
    assert (info["host"], info["dbname"], info["user"]) == (
        "direct.example.test", "maBase", "ecoute")
