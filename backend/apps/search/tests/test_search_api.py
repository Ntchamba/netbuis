"""Route de recherche (T041) : GET /api/search/."""
import json

import pytest
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.business.models import AccountType, BusinessStatus, Offer
from apps.geo.models import ZoneLevel
from apps.search.models import SearchLog, SearchMode
from apps.search.tests.helpers import make_zone, provider, shop
from tests.factories.business_factory import get_sector, make_owner, make_profile
from tests.factories.catalog_factory import make_sector
from tests.factories.storage_factory import make_stored_file
from tests.factories.zone_factory import make_maroua_chain

pytestmark = pytest.mark.django_db

URL = "/api/search/"


def connected(user=None):
    client = APIClient()
    client.credentials(
        HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user or make_owner())['access']}"
    )
    return client


def test_resultat_a_tous_les_champs_publics():
    owner = make_owner()
    photo = make_stored_file(owner)
    profile = shop(
        "Chez Riz", ["Riz parfumé"], owner=owner, photo=photo, repere="Près du marché",
        description_activite="Vente de riz en gros",
    )
    Offer.objects.create(profile=profile, name="Riz local", price_fcfa=12000)
    Offer.objects.create(profile=profile, name="Riz long", price_fcfa=15000)
    Offer.objects.create(profile=profile, name="Riz fantôme", price_fcfa=1, is_active=False)
    response = connected().get(URL, {"q": "riz"})
    assert response.status_code == 200
    (item,) = response.json()["results"]
    assert item["id"] == profile.pk and item["name"] == "Chez Riz"
    assert item["kind"] == "produit"
    assert item["secteur"] == "Alimentation" and item["secteur_code"] == "alimentation"
    assert item["zone"] == {"id": profile.zone_id, "name": profile.zone.name}
    assert item["repere"] == "Près du marché"
    assert item["description_activite"] == "Vente de riz en gros"
    assert item["photo"].endswith(photo)
    assert item["prix_indicatif"] == 12000
    assert item["verifie"] is False


def test_service_et_badge_verifie():
    profile = provider("Dépannage Paul", category=("technique_reparation", "Technique"),
                       cni_verifiee=True, photo="")
    (item,) = connected().get(URL, {"q": "technique"}).json()["results"]
    assert item["id"] == profile.pk and item["kind"] == "service"
    assert item["verifie"] is True and item["photo"] is None
    assert item["prix_indicatif"] is None and item["description_activite"] == ""


def test_aucun_numero_ni_piece_ni_badge_abonne_dans_la_reponse():
    secret = shop("Chez Riz", ["Riz"], subscribed=True)
    prest = provider("Paul", category=("technique_reparation", "Technique"), cni_verifiee=True)
    client = connected()
    for params in ({"q": "riz"}, {"q": ""}, {"q": "technique"}):
        text = json.dumps(client.get(URL, params).json(), ensure_ascii=False)
        for forbidden in (secret.phone_anchor, secret.phone_anchor[4:], prest.phone_anchor,
                          "+237", "phone", "cni_photo", prest.cni_photo,
                          prest.representant_photo, "motif_rejet", "subscri", "abonn"):
            assert forbidden not in text, forbidden
    keys = set(client.get(URL, {"q": "riz"}).json()["results"][0])
    assert keys == {
        "id", "name", "kind", "secteur", "secteur_code", "zone", "repere",
        "description_activite", "photo", "prix_indicatif", "verifie",
    }


def test_q_vide_liste_la_zone_abonnes_d_abord_et_sans_journal():
    _, _, _, maroua, harde = make_maroua_chain()
    ailleurs = make_zone("Garoua", ZoneLevel.VILLE_VILLAGE, maroua.parent)
    simple = shop("A simple", zone=harde)
    abonne = shop("Z abonné", zone=maroua, subscribed=True)
    shop("Hors zone", zone=ailleurs)
    shop("En attente", zone=harde, status=BusinessStatus.PENDING)
    response = connected().get(URL, {"zone": maroua.pk})
    assert response.status_code == 200
    assert [r["id"] for r in response.json()["results"]] == [abonne.pk, simple.pk]
    assert SearchLog.objects.count() == 0


def test_q_fournie_est_journalisee_en_mode_ecrit():
    shop("Chez Riz", ["Riz"])
    connected().get(URL, {"q": "Riz"})
    log = SearchLog.objects.get()
    assert (log.term, log.mode, log.results_count) == ("riz", SearchMode.TEXT, 1)


def test_filtre_secteur_par_code():
    cosmetique = make_sector(code="beaute", name="Beauté")
    a = shop("Salon", ["Savon"], secteur=cosmetique)
    shop("Epicerie", ["Savon"], secteur=get_sector())
    found = connected().get(URL, {"q": "savon", "sector": "beaute"}).json()["results"]
    ids = [r["id"] for r in found]
    assert ids == [a.pk]
    assert connected().get(URL, {"q": "savon", "sector": "inconnu"}).json()["results"] == []


def test_pagination_20_par_page():
    for i in range(23):
        make_profile(name=f"Boutique {i:02d}", status=BusinessStatus.ACTIVE)
    client = connected()
    first = client.get(URL).json()
    assert first["count"] == 23 and len(first["results"]) == 20 and first["next"]
    second = client.get(URL, {"page": 2}).json()
    assert len(second["results"]) == 3
    seen = {r["id"] for r in first["results"]} | {r["id"] for r in second["results"]}
    assert len(seen) == 23


def test_profil_invisible_jamais_renvoye():
    bloque = shop("Bloqué", ["Riz"])
    bloque.owner.is_blocked = True
    bloque.owner.save()
    rejete = shop("Rejeté", ["Riz"], status=BusinessStatus.REJECTED, motif_rejet="x")
    ids = [r["id"] for r in connected().get(URL, {"q": "riz"}).json()["results"]]
    assert bloque.pk not in ids and rejete.pk not in ids


def test_sans_connexion_401_et_compte_bloque_403():
    assert APIClient().get(URL).status_code == 401
    user = make_owner()
    client = connected(user)
    user.is_blocked = True
    user.save()
    assert client.get(URL).status_code == 403


def test_zone_inconnue_refusee():
    assert connected().get(URL, {"zone": 999999}).status_code == 400


def test_type_compte_structure_est_un_service():
    profile = make_profile(AccountType.STRUCTURE, status=BusinessStatus.ACTIVE, name="Hôtel Test")
    (item,) = connected().get(URL, {"q": ""}).json()["results"]
    assert item["id"] == profile.pk and item["kind"] == "service"
    assert item["secteur"] == "Restaurant" and item["secteur_code"] is None
