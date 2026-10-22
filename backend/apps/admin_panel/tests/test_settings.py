"""Réglages de plateforme (T074) : droits, bornes, clé inconnue, audit, cache."""
import pytest
from django.core.cache import cache

from apps.admin_panel.models import AuditAction, AuditLog
from apps.core.models import PlatformSetting
from apps.core.services.settings_service import get_setting

from ._t074 import COMPLET, VALIDATEUR, admin_in, api_as, check_permissions

pytestmark = pytest.mark.django_db

LIST = "/api/admin/settings/"
ONE = "/api/admin/settings/limite_appels_par_jour/"


@pytest.fixture(autouse=True)
def _cache():
    cache.clear()
    yield
    cache.clear()


def test_permissions_lecture():
    response = check_permissions("get", LIST, None, 200)
    assert [s["key"] for s in response.json()] == [
        "plafond_sous_categories_non_abonne", "plafond_publications_non_abonne",
        "limite_appels_par_minute", "limite_appels_par_jour", "seuil_appels_abonnement",
        "trends_min_searches", "trends_min_accounts", "trends_window_days",
    ]


def test_permissions_ecriture():
    check_permissions("patch", ONE, {"value": 40}, 200)


def test_lecture_donne_defaut_bornes_et_valeur_courante():
    admin = admin_in(COMPLET)
    PlatformSetting.objects.create(key="limite_appels_par_jour", value=77, modified_by=admin)
    rows = {s["key"]: s for s in api_as(admin).get(LIST).json()}
    day = rows["limite_appels_par_jour"]
    assert (day["value"], day["default"], day["min"], day["max"]) == (77, 50, 1, 1000)
    assert rows["limite_appels_par_minute"]["value"] == 5
    assert rows["limite_appels_par_minute"]["modified_by"] is None


def test_modification_ecrit_la_valeur_vide_le_cache_et_audite():
    admin = admin_in(COMPLET)
    assert get_setting("limite_appels_par_jour") == 50  # met 50 en cache
    response = api_as(admin).patch(ONE, {"value": 80, "reason": "essai terrain"}, format="json")
    assert response.status_code == 200 and response.json()["value"] == 80
    assert get_setting("limite_appels_par_jour") == 80
    row = PlatformSetting.objects.get(key="limite_appels_par_jour")
    assert row.modified_by == admin
    log = AuditLog.objects.get(action=AuditAction.MODIFICATION_REGLAGE)
    assert log.admin == admin and log.target_id == row.pk
    assert "limite_appels_par_jour : 50 -> 80" in log.reason and "essai terrain" in log.reason
    # second changement : ancienne valeur = 80
    api_as(admin).patch(ONE, {"value": 90}, format="json")
    assert AuditLog.objects.filter(reason__contains="80 -> 90").count() == 1


def test_valeur_identique_ne_cree_pas_d_audit():
    admin = admin_in(COMPLET)
    assert api_as(admin).patch(ONE, {"value": 50}, format="json").status_code == 200
    assert AuditLog.objects.count() == 0


@pytest.mark.parametrize("value", [0, -1, 1001, "12", 2.5, True, None, [1]])
def test_valeurs_refusees_rien_n_est_ecrit(value):
    admin = admin_in(COMPLET)
    response = api_as(admin).patch(ONE, {"value": value}, format="json")
    assert response.status_code == 400
    assert not PlatformSetting.objects.exists() and not AuditLog.objects.exists()


def test_valeur_manquante_et_bornes_acceptees():
    admin = admin_in(COMPLET)
    client = api_as(admin)
    assert client.patch(ONE, {}, format="json").status_code == 400
    assert client.patch(ONE, {"value": 1}, format="json").status_code == 200
    assert client.patch(ONE, {"value": 1000}, format="json").status_code == 200


def test_cle_inconnue_refusee():
    admin = admin_in(COMPLET)
    response = api_as(admin).patch("/api/admin/settings/n_importe_quoi/", {"value": 3},
                                   format="json")
    assert response.status_code == 400 and response.json()["code"] == "unknown_setting"
    assert not PlatformSetting.objects.exists() and not AuditLog.objects.exists()


def test_validateur_ne_modifie_rien():
    response = api_as(admin_in(VALIDATEUR)).patch(ONE, {"value": 3}, format="json")
    assert response.status_code == 403 and not PlatformSetting.objects.exists()
