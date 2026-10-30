"""Tendances (T104) : calcul avec seuil, fenêtre, villes, instantané, API sans numéro."""
import io
import json
from datetime import timedelta

import pytest
from django.core.cache import cache
from django.core.management import call_command
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.business.models import BusinessStatus
from apps.calls.models import CallChannel, CallLog, Platform
from apps.core.models.platform_setting import PlatformSetting
from apps.geo.models import ZoneLevel
from apps.search.models import SearchLog
from apps.search.services.logging import hash_account
from apps.trends.models import TrendEntry, TrendSnapshot
from apps.trends.services.compute_trends import compute_trends
from tests.factories.business_factory import make_owner, make_profile
from tests.factories.catalog_factory import make_product
from tests.factories.zone_factory import make_maroua_chain, make_zone

pytestmark = pytest.mark.django_db

URL = "/api/trends/"
PHONE_MARK = "+2376"


@pytest.fixture(autouse=True)
def _cache():
    cache.clear()
    yield
    cache.clear()


@pytest.fixture
def maroua():
    return make_maroua_chain()  # pays, région, département, ville, quartier


@pytest.fixture
def garoua(maroua):
    region = make_zone("Nord", ZoneLevel.REGION, maroua[0])
    dep = make_zone("Bénoué", ZoneLevel.DEPARTEMENT, region)
    return make_zone("Garoua", ZoneLevel.VILLE_VILLAGE, dep)


def users(n):
    return [make_owner() for _ in range(n)]


def search_log(term, zone, user=None, days_ago=0):
    log = SearchLog.objects.create(
        term=term, zone=zone, results_count=1, account_hash=hash_account(user))
    if days_ago:
        SearchLog.objects.filter(pk=log.pk).update(
            created_at=timezone.now() - timedelta(days=days_ago))
    return log


def searches(term, zone, n, accounts):
    people = users(accounts)
    for i in range(n):
        search_log(term, zone, people[i % accounts])


def contact(profile, caller, channel=CallChannel.CALL, days_ago=0):
    log = CallLog.objects.create(
        caller=caller, profile=profile, channel=channel, platform=Platform.ANDROID)
    if days_ago:
        CallLog.objects.filter(pk=log.pk).update(
            created_at=timezone.now() - timedelta(days=days_ago))


def contacts(profile, n, accounts, channel=CallChannel.CALL):
    people = users(accounts)
    for i in range(n):
        contact(profile, people[i % accounts], channel)


def shop(name, zone, **extra):
    extra.setdefault("status", BusinessStatus.ACTIVE)
    return make_profile(name=name, zone=zone, **extra)


def client():
    api = APIClient()
    api.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(make_owner())['access']}")
    return api


def get(zone):
    return client().get(URL, {"zone": zone.pk})


def kinds(city):
    snap = TrendSnapshot.objects.get(zone=city)
    return (
        list(snap.entries.filter(kind="product").values_list("product__name", flat=True)),
        list(snap.entries.filter(kind="business").values_list("profile__name", flat=True)),
    )


# --- seuil ---------------------------------------------------------------------------------

def test_seuil_4_recherches_rien(maroua):
    make_product("Riz")
    searches("riz", maroua[3], 4, 4)
    compute_trends()
    assert TrendEntry.objects.count() == 0
    assert get(maroua[3]).json()["products"] == []


def test_seuil_5_recherches_2_comptes_rien(maroua):
    make_product("Riz")
    searches("riz", maroua[3], 5, 2)
    compute_trends()
    assert TrendEntry.objects.count() == 0


def test_seuil_5_recherches_3_comptes_classe(maroua):
    make_product("Riz")
    searches("riz", maroua[3], 5, 3)
    compute_trends()
    body = get(maroua[3]).json()
    assert [p["name"] for p in body["products"]] == ["Riz"]
    assert body["products"][0]["rank"] == 1
    assert body["zone"] == {"id": maroua[3].pk, "name": "Maroua"}
    assert body["period_days"] == 7


def test_recherches_anonymes_ne_comptent_pas_comme_comptes(maroua):
    make_product("Riz")
    for _ in range(8):
        search_log("riz", maroua[3], None)
    compute_trends()
    assert TrendEntry.objects.count() == 0


def test_seuils_lus_dans_platform_setting(maroua):
    make_product("Riz")
    searches("riz", maroua[3], 3, 2)
    compute_trends()
    assert TrendEntry.objects.count() == 0
    PlatformSetting.objects.create(key="trends_min_searches", value=3)
    PlatformSetting.objects.create(key="trends_min_accounts", value=2)
    cache.clear()
    compute_trends()
    assert kinds(maroua[3])[0] == ["Riz"]


def test_fenetre_lue_dans_platform_setting(maroua):
    make_product("Riz")
    people = users(3)
    for i in range(6):
        search_log("riz", maroua[3], people[i % 3], days_ago=10)
    compute_trends()
    assert TrendEntry.objects.count() == 0
    PlatformSetting.objects.create(key="trends_window_days", value=14)
    cache.clear()
    compute_trends()
    assert kinds(maroua[3])[0] == ["Riz"]
    assert TrendSnapshot.objects.get().window_days == 14


# --- fenêtre, villes -----------------------------------------------------------------------

def test_recherches_de_plus_de_7_jours_exclues(maroua):
    make_product("Riz")
    people = users(3)
    for i in range(6):
        search_log("riz", maroua[3], people[i % 3], days_ago=8)
    compute_trends()
    assert TrendEntry.objects.count() == 0
    for i in range(3):  # 3 récentes + ... : 3 < 5, toujours rien
        search_log("riz", maroua[3], people[i])
    compute_trends()
    assert TrendEntry.objects.count() == 0


def test_contacts_anciens_exclus(maroua):
    boutique = shop("Chez Ali", maroua[3])
    people = users(3)
    for i in range(6):
        contact(boutique, people[i % 3], days_ago=9)
    compute_trends()
    assert TrendEntry.objects.count() == 0


def test_par_ville_maroua_different_de_garoua(maroua, garoua):
    make_product("Riz")
    make_product("Mil")
    searches("riz", maroua[3], 5, 3)
    searches("mil", garoua, 5, 3)
    compute_trends()
    assert kinds(maroua[3])[0] == ["Riz"]
    assert kinds(garoua)[0] == ["Mil"]
    assert [p["name"] for p in get(garoua).json()["products"]] == ["Mil"]


def test_quartier_ramene_a_sa_ville_et_comptes_additionnes(maroua):
    make_product("Riz")
    second = make_zone("Domayo", ZoneLevel.QUARTIER, maroua[3])
    people = users(3)
    for i, zone in enumerate([maroua[4], maroua[4], second, second, maroua[3]]):
        search_log("riz", zone, people[i % 3])
    compute_trends()
    assert kinds(maroua[3])[0] == ["Riz"]
    # l'API accepte aussi un quartier et répond avec sa ville
    body = get(maroua[4]).json()
    assert body["zone"]["name"] == "Maroua" and [p["name"] for p in body["products"]] == ["Riz"]


def test_synonyme_compte_pour_le_produit_et_texte_libre_ignore(maroua):
    from apps.catalog.models import Synonym

    riz = make_product("Riz")
    Synonym.objects.create(product=riz, term="riz local")
    searches("riz local", maroua[3], 5, 3)
    searches("mon numéro 655000000", maroua[3], 9, 5)  # texte libre : jamais classé
    compute_trends()
    assert kinds(maroua[3])[0] == ["Riz"]
    assert "655" not in json.dumps(get(maroua[3]).json())


def test_produit_inactif_ignore(maroua):
    make_product("Riz", is_active=False)
    searches("riz", maroua[3], 5, 3)
    compute_trends()
    assert TrendEntry.objects.count() == 0


# --- commerces -----------------------------------------------------------------------------

def test_appels_et_whatsapp_comptent(maroua):
    boutique = shop("Chez Ali", maroua[3])
    people = users(3)
    contact(boutique, people[0], CallChannel.CALL)
    contact(boutique, people[1], CallChannel.WHATSAPP)
    contact(boutique, people[2], CallChannel.WHATSAPP)
    contact(boutique, people[0], CallChannel.CALL)
    contact(boutique, people[1], CallChannel.CALL)
    compute_trends()
    body = get(maroua[3]).json()
    assert body["businesses"] == [
        {"id": boutique.pk, "name": "Chez Ali", "rank": 1,
         "zone": {"id": maroua[3].pk, "name": "Maroua"}}]


def test_commerces_non_actifs_exclus(maroua):
    attente = shop("En attente", maroua[3], status=BusinessStatus.PENDING)
    rejete = shop("Rejeté", maroua[3], status=BusinessStatus.REJECTED, motif_rejet="x")
    suspendu = shop("Suspendu", maroua[3])
    supprime = shop("Supprimé", maroua[3])
    ok = shop("Actif", maroua[3])
    for profile in (attente, rejete, suspendu, supprime, ok):
        contacts(profile, 5, 3)
    suspendu.owner.is_blocked = True
    suspendu.owner.save()
    supprime.owner.is_deleted = True
    supprime.owner.save()
    compute_trends()
    assert kinds(maroua[3])[1] == ["Actif"]
    assert [b["name"] for b in get(maroua[3]).json()["businesses"]] == ["Actif"]


def test_commerce_suspendu_apres_calcul_disparait_de_la_reponse(maroua):
    boutique = shop("Chez Ali", maroua[3])
    contacts(boutique, 5, 3)
    compute_trends()
    assert len(get(maroua[3]).json()["businesses"]) == 1
    boutique.owner.is_blocked = True
    boutique.owner.save()
    assert get(maroua[3]).json()["businesses"] == []  # relu sans recalcul


def test_commerce_sous_le_seuil_non_classe(maroua):
    contacts(shop("Peu", maroua[3]), 5, 2)
    contacts(shop("Trop peu", maroua[3]), 4, 4)
    compute_trends()
    assert TrendEntry.objects.count() == 0


def test_commerce_classe_dans_la_ville_de_son_quartier(maroua, garoua):
    boutique = shop("Chez Ali", maroua[4])  # quartier de Maroua
    contacts(boutique, 5, 3)
    compute_trends()
    assert [b["name"] for b in get(maroua[3]).json()["businesses"]] == ["Chez Ali"]
    assert get(garoua).json()["businesses"] == []


def test_au_plus_10_produits_et_10_commerces(maroua):
    for i in range(12):
        make_product(f"Produit {i:02d}")
        searches(f"produit {i:02d}", maroua[3], 5 + i, 3)
        contacts(shop(f"Commerce {i:02d}", maroua[3]), 5 + i, 3)
    compute_trends()
    body = get(maroua[3]).json()
    assert len(body["products"]) == 10 and len(body["businesses"]) == 10
    assert body["products"][0]["name"] == "Produit 11"
    assert [p["rank"] for p in body["products"]] == list(range(1, 11))


# --- sécurité de la réponse ------------------------------------------------------------------

def test_aucun_numero_ni_compte_dans_la_reponse(maroua):
    make_product("Riz")
    searches("riz", maroua[3], 5, 3)
    boutique = shop("Chez Ali", maroua[3], phone_anchor="+237655012345")
    contacts(boutique, 5, 3)
    compute_trends()
    response = get(maroua[3])
    text = json.dumps(response.json())
    assert response.json()["businesses"] and response.json()["products"]
    for forbidden in ("655012345", PHONE_MARK, "phone", "telephone", "owner", "user",
                      "account", "caller", "hash", "wa.me"):
        assert forbidden not in text.lower()

    def keys(node):
        if isinstance(node, dict):
            for key, value in node.items():
                yield key
                yield from keys(value)
        elif isinstance(node, list):
            for item in node:
                yield from keys(item)

    assert set(keys(response.json())) <= {
        "zone", "id", "name", "computed_at", "period_days", "products", "businesses", "rank"}


# --- instantané, commande ----------------------------------------------------------------------

def test_api_ne_recalcule_pas(maroua):
    make_product("Riz")
    api = client()
    assert api.get(URL, {"zone": maroua[3].pk}).json()["products"] == []
    searches("riz", maroua[3], 5, 3)
    assert api.get(URL, {"zone": maroua[3].pk}).json()["products"] == []  # pas de calcul
    compute_trends()
    assert len(api.get(URL, {"zone": maroua[3].pk}).json()["products"]) == 1


def test_commande_idempotente_remplace_l_instantane(maroua):
    make_product("Riz")
    searches("riz", maroua[3], 5, 3)
    out = io.StringIO()
    call_command("compute_trends", stdout=out)
    first = TrendSnapshot.objects.get().pk
    searches("riz", maroua[3], 5, 3)
    call_command("compute_trends", stdout=out)
    assert TrendSnapshot.objects.count() == 1
    assert TrendSnapshot.objects.get().pk != first
    assert TrendEntry.objects.count() == 1
    assert "1 ville" in out.getvalue()


def test_ancien_classement_vide_quand_plus_rien_ne_passe_le_seuil(maroua):
    make_product("Riz")
    searches("riz", maroua[3], 5, 3)
    compute_trends(now=timezone.now() - timedelta(days=3))  # instantané plus ancien
    SearchLog.objects.all().delete()
    compute_trends()
    assert get(maroua[3]).json()["products"] == []
    assert TrendSnapshot.objects.count() == 2


# --- accès ---------------------------------------------------------------------------------

def test_sans_authentification_refuse(maroua):
    assert APIClient().get(URL, {"zone": maroua[3].pk}).status_code == 401


def test_compte_bloque_refuse(maroua):
    user = make_owner(is_blocked=True)
    api = APIClient()
    api.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    assert api.get(URL, {"zone": maroua[3].pk}).status_code in (401, 403)


def test_zone_inconnue_ou_absente_400(maroua):
    api = client()
    assert api.get(URL, {"zone": 999999}).status_code == 400
    assert api.get(URL).status_code == 400


def test_ville_sans_instantane_listes_vides(maroua, garoua):
    body = get(garoua).json()
    assert body["products"] == [] and body["businesses"] == []
    assert body["zone"]["name"] == "Garoua"


def test_zone_au_dessus_d_une_ville_listes_vides(maroua):
    body = get(maroua[2]).json()  # département
    assert body["zone"] is None and body["products"] == [] and body["businesses"] == []
