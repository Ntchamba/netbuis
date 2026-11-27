"""Chiffres du tableau de bord (T073) : droits, valeurs, bornes, abonnés, numéros, requêtes."""
from datetime import timedelta

import pytest
from django.contrib.auth.models import Group
from django.core.cache import cache
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.accounts.services.token_service import issue_tokens
from apps.admin_panel.services import stats_service
from apps.business.models import BusinessStatus
from apps.calls.models import CallChannel, CallLog, Platform
from apps.core.models import PlatformSetting, SettingKey
from apps.geo.models import ZoneLevel
from apps.search.models import SearchLog
from tests.factories.business_factory import make_owner, make_profile, make_subscription
from tests.factories.user_factory import AdminFactory, UserFactory
from tests.factories.zone_factory import make_maroua_chain, make_zone

pytestmark = pytest.mark.django_db

URL = "/api/admin/stats/"
WEEK = timedelta(days=7)


@pytest.fixture(autouse=True)
def _cache():
    cache.clear()
    yield
    cache.clear()


def admin_in(group):
    admin = make_owner(is_admin=True)  # même compteur de numéros que les profils (pas de collision)
    admin.groups.add(Group.objects.get(name=group))
    return admin


def api_as(user):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    return client


def shop(**extra):
    extra.setdefault("status", BusinessStatus.ACTIVE)
    return make_profile(**extra)


def calls(profile, n, at=None):
    caller = make_owner()
    rows = [CallLog.objects.create(caller=caller, profile=profile,
                                   channel=CallChannel.CALL, platform=Platform.ANDROID)
            for _ in range(n)]
    if at is not None:
        CallLog.objects.filter(pk__in=[r.pk for r in rows]).update(created_at=at)


def set_threshold(value):
    PlatformSetting.objects.create(key=SettingKey.SEUIL_APPELS_ABONNEMENT, value=value)
    cache.clear()


# --- Droits -----------------------------------------------------------------------------


def test_anonyme_401_utilisateur_et_admin_sans_groupe_403():
    assert APIClient().get(URL).status_code == 401
    assert api_as(UserFactory()).get(URL).status_code == 403
    assert api_as(AdminFactory()).get(URL).status_code == 403


@pytest.mark.parametrize("group", ["Validateur", "Administrateur complet"])
def test_validateur_et_admin_complet_200(group):
    response = api_as(admin_in(group)).get(URL)
    assert response.status_code == 200
    assert response["Cache-Control"] == "no-store"


def test_admin_bloque_403():
    admin = admin_in("Administrateur complet")
    client = api_as(admin)
    User.objects.filter(pk=admin.pk).update(is_blocked=True)
    assert client.get(URL).status_code == 403


def test_methode_ecriture_refusee():
    assert api_as(admin_in("Administrateur complet")).post(URL, {}).status_code == 405


# --- Valeurs ----------------------------------------------------------------------------


def test_base_vide():
    data = api_as(admin_in("Validateur")).get(URL).json()
    assert data["accounts_total"] == 1  # l'admin lui-même
    assert data["active_businesses"] == 0 and data["neighborhoods_covered"] == 0
    assert data["pending_requests"] == 0 and data["calls_week"] == 0
    assert data["searches_week"] == 0 and data["subscribers"] == 0
    assert data["high_traffic"] == [] and data["high_traffic_count"] == 0
    assert data["subscription_threshold"] == 10  # défaut D-11


def test_revenus_indisponibles():
    data = api_as(admin_in("Validateur")).get(URL).json()
    assert data["revenue_month"] == {"amount": 0, "currency": "FCFA", "unavailable": True}


def test_comptes_et_business():
    _, _, _, ville, harde = make_maroua_chain()
    domayo = make_zone("Domayo", ZoneLevel.QUARTIER, ville)
    shop(zone=harde)
    shop(zone=harde)
    shop(zone=domayo)
    shop(zone=ville)  # actif mais en ville : pas un quartier
    make_profile(status=BusinessStatus.PENDING, zone=harde)
    make_profile(status=BusinessStatus.REJECTED, zone=domayo, motif_rejet="Photo floue")
    bloque = shop(zone=harde)
    User.objects.filter(pk=bloque.owner_id).update(is_blocked=True)
    supprime = shop(zone=domayo)
    User.objects.filter(pk=supprime.owner_id).update(is_deleted=True)
    en_attente_supprime = make_profile(status=BusinessStatus.PENDING, zone=harde)
    User.objects.filter(pk=en_attente_supprime.owner_id).update(is_deleted=True)

    data = api_as(admin_in("Validateur")).get(URL).json()
    assert data["active_businesses"] == 4  # ni bloqué, ni supprimé, ni attente, ni rejeté
    assert data["neighborhoods_covered"] == 2
    assert data["pending_requests"] == 1  # le dossier du compte supprimé n'est pas compté
    # 9 propriétaires + 1 admin - 2 supprimés
    assert data["accounts_total"] == User.objects.filter(is_deleted=False).count() == 8


def test_fenetre_glissante_appels_recherches_aux_bornes():
    now = timezone.now()
    profile = shop()
    for label, delta in (("pile", WEEK), ("avant", WEEK + timedelta(seconds=1)),
                         ("apres", WEEK - timedelta(seconds=1))):
        calls(profile, 1, at=now - delta)
        log = SearchLog.objects.create(term=label)
        SearchLog.objects.filter(pk=log.pk).update(created_at=now - delta)
    data = stats_service.compute(now=now)
    assert data["calls_week"] == 2  # « pile » et « après » ; « avant » est hors fenêtre
    assert data["searches_week"] == 2


def test_comptes_nouveaux_bornes():
    now = timezone.now()
    base = stats_service.compute(now=now)["accounts_new_week"]
    for delta in (WEEK, WEEK + timedelta(seconds=1), timedelta(0)):
        user = make_owner()
        User.objects.filter(pk=user.pk).update(created_at=now - delta)
    assert stats_service.compute(now=now)["accounts_new_week"] == base + 2
    ancien = make_owner()
    User.objects.filter(pk=ancien.pk).update(created_at=now - timedelta(days=60))
    assert stats_service.compute(now=now)["accounts_new_week"] == base + 2


# --- Abonnés et fort trafic -------------------------------------------------------------


def test_abonnes_comptes_parmi_actifs_et_non_echus():
    now = timezone.now()
    make_subscription(shop())
    make_subscription(shop(), start=now - timedelta(days=10), end=now - timedelta(days=1))
    make_subscription(make_profile(status=BusinessStatus.PENDING))  # pas actif
    data = api_as(admin_in("Validateur")).get(URL).json()
    assert data["subscribers"] == 1 and data["active_businesses"] == 2


def test_fort_trafic_seuil_lu_en_base_strictement_superieur_non_abonnes():
    set_threshold(3)
    a, b, egal, abonne, bloque, vieux = (shop(name=n) for n in "ABEXYZ")
    calls(a, 5)
    calls(b, 4)
    calls(egal, 3)  # égal au seuil : pas au-dessus
    calls(abonne, 9)
    make_subscription(abonne)
    calls(bloque, 9)
    User.objects.filter(pk=bloque.owner_id).update(is_blocked=True)
    calls(vieux, 9, at=timezone.now() - timedelta(hours=25))  # hors des 24 h
    data = api_as(admin_in("Validateur")).get(URL).json()
    assert data["subscription_threshold"] == 3
    assert data["high_traffic"] == [
        {"id": a.pk, "name": "A", "calls_per_day": 5},
        {"id": b.pk, "name": "B", "calls_per_day": 4},
    ]
    assert data["high_traffic_count"] == 2


def test_fort_trafic_borne_24h():
    set_threshold(1)
    now = timezone.now()
    dedans, dehors = shop(name="D"), shop(name="O")
    calls(dedans, 2, at=now - timedelta(hours=24))
    calls(dehors, 2, at=now - timedelta(hours=24, seconds=1))
    rows = stats_service.compute(now=now)["high_traffic"]
    assert [r["id"] for r in rows] == [dedans.pk]


def test_fort_trafic_limite_a_dix_lignes_mais_compte_total():
    set_threshold(1)
    for i in range(12):
        calls(shop(name=f"S{i}"), 2)
    data = api_as(admin_in("Validateur")).get(URL).json()
    assert len(data["high_traffic"]) == 10 and data["high_traffic_count"] == 12


# --- Confidentialité --------------------------------------------------------------------


def test_aucun_numero_dans_la_reponse():
    set_threshold(1)
    profile = shop(name="Mama Aïcha")
    calls(profile, 3)
    admin = admin_in("Administrateur complet")
    body = api_as(admin).get(URL).content.decode()
    assert profile.phone_anchor not in body
    assert profile.owner.phone not in body and admin.phone not in body
    assert "+237" not in body and "phone" not in body


# --- Requêtes ---------------------------------------------------------------------------


def _count_queries(client):
    with CaptureQueriesContext(connection) as ctx:
        assert client.get(URL).status_code == 200
    return len(ctx)


def test_nombre_de_requetes_constant():
    set_threshold(1)
    client = api_as(admin_in("Validateur"))
    client.get(URL)  # chauffe (types de contenu, etc.)
    avant = _count_queries(client)
    for i in range(6):
        p = shop(name=f"N{i}")
        calls(p, 3)
        if i % 2:
            make_subscription(p)
        SearchLog.objects.create(term="riz")
    make_profile(status=BusinessStatus.PENDING)
    apres = _count_queries(client)
    assert apres == avant
