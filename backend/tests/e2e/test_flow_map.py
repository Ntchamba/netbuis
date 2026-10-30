"""Parcours de la carte par zones (T123) : villes → quartiers → commerces d'un quartier,
et effet de la validation ou du blocage d'un commerce sur la carte.
"""
import json

import pytest
from django.core.cache import cache

from apps.business.models import BusinessStatus
from apps.geo.models import ZoneLevel
from apps.search.tests.helpers import shop
from tests.e2e._aides import COMPLET, VALIDATEUR, administrateur, client_de, compte
from tests.factories.zone_factory import make_maroua_chain, make_zone

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def _cache():
    cache.clear()
    yield
    cache.clear()


def test_villes_puis_quartiers_puis_commerces_et_effet_de_la_moderation():
    _, _, departement, maroua, harde = make_maroua_chain()
    doualare = make_zone("Doualaré", ZoneLevel.QUARTIER, maroua)
    make_zone("Garoua", ZoneLevel.VILLE_VILLAGE, departement)  # aucune activité : absente
    a = shop("Chez Riz", ["Riz", "Huile"], zone=harde)
    shop("Boutique B", ["Savon"], zone=harde)
    shop("Boutique C", zone=doualare)
    en_attente = shop("Boutique D", zone=harde, status=BusinessStatus.PENDING)
    visiteur = client_de(compte())

    # 1. Niveau 1 : seules les villes qui ont un commerce actif sont proposées.
    villes = visiteur.get("/api/map/cities/")
    assert villes.status_code == 200
    assert [c["name"] for c in villes.json()["cities"]] == ["Maroua"]
    ville = villes.json()["cities"][0]
    assert ville["businesses_count"] == 3  # le commerce en attente n'est pas compté

    # 2. Niveau 2 : les quartiers de la ville, avec leurs compteurs.
    quartiers = visiteur.get(f"/api/map/cities/{ville['id']}/areas/")
    assert quartiers.status_code == 200
    par_nom = {q["name"]: q for q in quartiers.json()["areas"]}
    assert set(par_nom) == {"Hardé", "Doualaré"}
    assert par_nom["Hardé"]["businesses_count"] == 2
    assert par_nom["Hardé"]["products_count"] == 3

    # 3. Niveau 3 : les commerces du quartier, sans numéro de téléphone.
    commerces = visiteur.get(f"/api/map/areas/{harde.pk}/businesses/")
    assert commerces.status_code == 200
    assert {c["name"] for c in commerces.json()["results"]} == {"Chez Riz", "Boutique B"}
    assert "+237" not in json.dumps(commerces.json()) and a.phone_anchor not in str(
        commerces.json())

    # 4. Les mauvais niveaux sont refusés : un quartier n'est pas une ville, et inversement.
    assert visiteur.get(f"/api/map/cities/{harde.pk}/areas/").status_code == 404
    assert visiteur.get(f"/api/map/areas/{maroua.pk}/businesses/").status_code == 404

    # 5. L'administrateur valide la demande en attente : le quartier gagne un commerce.
    assert client_de(administrateur(VALIDATEUR)).post(
        f"/api/admin/requests/{en_attente.pk}/approve/").status_code == 200
    noms = {c["name"] for c in visiteur.get(
        f"/api/map/areas/{harde.pk}/businesses/").json()["results"]}
    assert noms == {"Chez Riz", "Boutique B", "Boutique D"}

    # 6. Il bloque le propriétaire de « Chez Riz » : le commerce disparaît de la carte.
    assert client_de(administrateur(COMPLET)).post(
        f"/api/admin/accounts/{a.owner_id}/block/", {"reason": "Fraude"}, format="json"
    ).status_code == 200
    noms = {c["name"] for c in visiteur.get(
        f"/api/map/areas/{harde.pk}/businesses/").json()["results"]}
    assert noms == {"Boutique B", "Boutique D"}
    assert visiteur.get("/api/map/cities/").json()["cities"][0]["businesses_count"] == 3


def test_la_carte_exige_une_connexion():
    from rest_framework.test import APIClient

    assert APIClient().get("/api/map/cities/").status_code == 401
