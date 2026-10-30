"""Réglages de plateforme : T008b (modèle, get_setting, cache, admin Django)."""
import secrets

import pytest
from django.core.cache import cache
from django.core.exceptions import ValidationError
from django.test import Client

from apps.core.models import DEFAULTS, PlatformSetting, SettingKey, UnknownSettingError
from apps.core.services.settings_service import CACHE_TIMEOUT, cache_key, get_setting
from tests.factories.user_factory import AdminFactory

pytestmark = pytest.mark.django_db

ADMIN_URL = "/django-admin/core/platformsetting/"
APPELS_MINUTE = SettingKey.LIMITE_APPELS_PAR_MINUTE.value


@pytest.fixture(autouse=True)
def _cache():
    cache.clear()
    yield
    cache.clear()


@pytest.fixture
def browser():
    admin = AdminFactory(password=secrets.token_urlsafe(16), is_staff=True, is_superuser=True)
    client = Client()
    client.force_login(admin)
    client.admin = admin
    return client


# --- Défauts ---------------------------------------------------------------------


def test_defauts_declares_une_seule_fois():
    assert DEFAULTS == {
        "plafond_sous_categories_non_abonne": 3,
        "plafond_publications_non_abonne": 5,
        "limite_appels_par_minute": 5,
        "limite_appels_par_jour": 50,
        "seuil_appels_abonnement": 10,
        "trends_min_searches": 5,
        "trends_min_accounts": 3,
        "trends_window_days": 7,
    }
    assert set(DEFAULTS) == set(SettingKey.values)


@pytest.mark.parametrize("key", SettingKey.values)
def test_defaut_sans_ligne_en_base(key):
    value = get_setting(key)
    assert value == DEFAULTS[key]
    assert type(value) is int


# --- Valeur modifiée et cache ----------------------------------------------------


def test_valeur_modifiee_lue():
    PlatformSetting.objects.create(key=APPELS_MINUTE, value=7)
    assert get_setting(APPELS_MINUTE) == 7


def test_lecture_mise_en_cache_courte(django_assert_num_queries):
    PlatformSetting.objects.create(key=APPELS_MINUTE, value=7)
    with django_assert_num_queries(1):
        assert get_setting(APPELS_MINUTE) == 7
        assert get_setting(APPELS_MINUTE) == 7  # second appel servi par le cache
    assert cache.get(cache_key(APPELS_MINUTE)) == 7
    assert 0 < CACHE_TIMEOUT <= 60


def test_cache_invalide_a_la_sauvegarde():
    setting = PlatformSetting.objects.create(key=APPELS_MINUTE, value=7)
    assert get_setting(APPELS_MINUTE) == 7
    setting.value = 9
    setting.save()
    assert get_setting(APPELS_MINUTE) == 9


def test_cache_invalide_a_la_creation():
    assert get_setting(APPELS_MINUTE) == 5  # défaut mis en cache
    PlatformSetting.objects.create(key=APPELS_MINUTE, value=8)
    assert get_setting(APPELS_MINUTE) == 8


def test_cache_invalide_a_la_suppression_retour_au_defaut():
    setting = PlatformSetting.objects.create(key=APPELS_MINUTE, value=7)
    assert get_setting(APPELS_MINUTE) == 7
    setting.delete()
    assert get_setting(APPELS_MINUTE) == 5


def test_cache_invalide_apres_validation_de_la_transaction(django_capture_on_commit_callbacks):
    setting = PlatformSetting.objects.create(key=APPELS_MINUTE, value=7)
    with django_capture_on_commit_callbacks(execute=True):
        setting.value = 12
        setting.save()
        # Lecture pendant la transaction : la nouvelle valeur est déjà visible ici,
        # mais un autre lecteur aurait pu remettre l'ancienne en cache.
        cache.set(cache_key(APPELS_MINUTE), 7)
    assert get_setting(APPELS_MINUTE) == 12


# --- Clé inconnue ----------------------------------------------------------------


def test_lecture_cle_inconnue_erreur_claire():
    with pytest.raises(UnknownSettingError) as exc:
        get_setting("plafond_inexistant")
    assert "plafond_inexistant" in str(exc.value)
    assert exc.value.key == "plafond_inexistant"


def test_ecriture_cle_inconnue_refusee():
    with pytest.raises(ValidationError) as exc:
        PlatformSetting.objects.create(key="plafond_inexistant", value=3)
    assert "plafond_inexistant" in str(exc.value.message_dict["key"])
    assert not PlatformSetting.objects.exists()


# --- Valeurs invalides -----------------------------------------------------------


@pytest.mark.parametrize("value", [0, -1, "abc", "2.5", 2.5, True, None])
def test_valeur_invalide_refusee_a_l_ecriture(value):
    with pytest.raises(ValidationError) as exc:
        PlatformSetting.objects.create(key=APPELS_MINUTE, value=value)
    assert "value" in exc.value.message_dict
    assert not PlatformSetting.objects.exists()


def test_cle_unique():
    PlatformSetting.objects.create(key=APPELS_MINUTE, value=7)
    with pytest.raises(ValidationError):
        PlatformSetting(key=APPELS_MINUTE, value=8).validate_unique()


# --- Admin Django ----------------------------------------------------------------


def test_admin_liste_visible(browser):
    PlatformSetting.objects.create(key=APPELS_MINUTE, value=7)
    response = browser.get(ADMIN_URL)
    assert response.status_code == 200
    assert APPELS_MINUTE in response.content.decode()


def test_admin_cle_choisie_dans_la_liste(browser):
    response = browser.get(f"{ADMIN_URL}add/")
    assert response.status_code == 200
    html = response.content.decode()
    assert '<select name="key"' in html
    for key in SettingKey.values:
        assert f'value="{key}"' in html


def test_admin_creation_remplit_modifie_par_et_invalide_le_cache(browser):
    assert get_setting(APPELS_MINUTE) == 5
    response = browser.post(f"{ADMIN_URL}add/", {"key": APPELS_MINUTE, "value": "6"})
    assert response.status_code == 302
    setting = PlatformSetting.objects.get(key=APPELS_MINUTE)
    assert setting.modified_by == browser.admin
    assert setting.updated_at is not None
    assert get_setting(APPELS_MINUTE) == 6


def test_admin_modification_remplit_modifie_par(browser):
    autre = AdminFactory()
    setting = PlatformSetting.objects.create(key=APPELS_MINUTE, value=7, modified_by=autre)
    assert get_setting(APPELS_MINUTE) == 7
    response = browser.post(f"{ADMIN_URL}{setting.pk}/change/", {"value": "4"})
    assert response.status_code == 302
    setting.refresh_from_db()
    assert setting.value == 4
    assert setting.modified_by == browser.admin
    assert get_setting(APPELS_MINUTE) == 4


@pytest.mark.parametrize("value", ["0", "-3", "abc", "2.5", ""])
def test_admin_valeur_invalide_refusee(browser, value):
    response = browser.post(f"{ADMIN_URL}add/", {"key": APPELS_MINUTE, "value": value})
    assert response.status_code == 200  # formulaire réaffiché avec l'erreur
    assert response.context["adminform"].form.errors["value"]
    assert not PlatformSetting.objects.exists()


def test_admin_cle_inconnue_refusee(browser):
    response = browser.post(f"{ADMIN_URL}add/", {"key": "plafond_inexistant", "value": "3"})
    assert response.status_code == 200
    assert response.context["adminform"].form.errors["key"]
    assert not PlatformSetting.objects.exists()


def test_admin_suppression_groupee_retour_au_defaut(browser):
    setting = PlatformSetting.objects.create(key=APPELS_MINUTE, value=7)
    assert get_setting(APPELS_MINUTE) == 7
    response = browser.post(
        ADMIN_URL,
        {"action": "delete_selected", "_selected_action": [setting.pk], "post": "yes"},
    )
    assert response.status_code == 302
    assert not PlatformSetting.objects.exists()
    assert get_setting(APPELS_MINUTE) == 5


def test_admin_suppression_unitaire_retour_au_defaut(browser):
    setting = PlatformSetting.objects.create(key=APPELS_MINUTE, value=7)
    assert get_setting(APPELS_MINUTE) == 7
    response = browser.post(f"{ADMIN_URL}{setting.pk}/delete/", {"post": "yes"})
    assert response.status_code == 302
    assert get_setting(APPELS_MINUTE) == 5
