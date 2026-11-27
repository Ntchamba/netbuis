"""Les jetons signés des chemins ne figurent jamais dans les journaux (T071, T089)."""
import logging

import pytest
from rest_framework.test import APIClient

from apps.admin_panel.log_filters import SignedLinkFilter

pytestmark = pytest.mark.django_db

FAUX_JETON = "JETONFICTIF-abc123.def456"


@pytest.mark.parametrize("path", [
    f"/api/uploads/local/{FAUX_JETON}/",
    f"/api/admin/private-files/{FAUX_JETON}/",
])
def test_requete_refusee_ne_journalise_pas_le_jeton(caplog, path):
    with caplog.at_level(logging.DEBUG):
        APIClient().put(path, b"x", content_type="application/octet-stream")
    assert caplog.records, "la requête refusée devrait être journalisée"
    assert FAUX_JETON not in caplog.text
    for record in caplog.records:
        assert FAUX_JETON not in repr(record.__dict__)
    assert "[lien masqué]" in caplog.text


def test_serveur_de_developpement_masque_le_jeton(caplog):
    logger = logging.getLogger("django.server")
    with caplog.at_level(logging.INFO, logger="django.server"):
        logger.info("%s", f'"PUT /api/uploads/local/{FAUX_JETON}/ HTTP/1.1" 200 0')
    assert FAUX_JETON not in caplog.text
    assert '"PUT /api/uploads/local/[lien masqué]/ HTTP/1.1" 200 0' in caplog.text


def test_autres_lignes_inchangees():
    record = logging.LogRecord("django.request", logging.WARNING, "f", 1,
                               "Not Found: %s", ("/api/search/",), None)
    SignedLinkFilter().filter(record)
    assert record.getMessage() == "Not Found: /api/search/"


def test_filtre_pose_sur_les_journaux_django():
    for name in ("django.request", "django.server"):
        assert any(isinstance(f, SignedLinkFilter) for f in logging.getLogger(name).filters)
