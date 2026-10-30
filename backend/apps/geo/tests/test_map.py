"""Carte par zones (T060) : villes actives, quartiers, commerces d'un quartier."""
import json

import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.business.models import BusinessProfile, BusinessStatus, Offer
from apps.geo.models import ZoneLevel
from apps.search.tests.helpers import provider, shop
from tests.factories.business_factory import make_owner
from tests.factories.zone_factory import make_maroua_chain, make_zone

pytestmark = pytest.mark.django_db

CITIES = "/api/map/cities/"


def connected(user=None):
    client = APIClient()
    client.credentials(
        HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user or make_owner())['access']}"
    )
    return client


def by_name(items):
    return {item["name"]: item for item in items}


def test_acces_refuse_sans_connexion_ou_bloque():
    assert APIClient().get(CITIES).status_code == 401
    assert connected(make_owner(is_blocked=True)).get(CITIES).status_code == 403


def test_seules_les_villes_avec_commerce_actif_apparaissent():
    _, region, dep, maroua, harde = make_maroua_chain()
    garoua = make_zone("Garoua", ZoneLevel.VILLE_VILLAGE, dep)  # aucun commerce
    mokolo = make_zone("Mokolo", ZoneLevel.VILLE_VILLAGE, dep)  # seulement en attente
    shop("A", zone=harde)
    shop("B", zone=maroua)
    shop("C", zone=mokolo, status=BusinessStatus.PENDING)
    data = connected().get(CITIES).json()
    cities = by_name(data["cities"])
    assert set(cities) == {"Maroua"}
    assert cities["Maroua"]["businesses_count"] == 2  # directement + par le quartier
    assert garoua.name not in cities
    assert cities["Maroua"]["region"] == {"id": region.pk, "name": "Extrême-Nord",
                                          "explorable": True}
    assert cities["Maroua"]["departement"]["name"] == "Diamaré"


def test_proprietaire_bloque_ou_supprime_non_compte():
    _, _, dep, maroua, harde = make_maroua_chain()
    shop("A", zone=harde, owner=make_owner(is_blocked=True))
    shop("B", zone=harde, owner=make_owner(is_deleted=True))
    assert connected().get(CITIES).json()["cities"] == []
    shop("C", zone=maroua)
    (city,) = connected().get(CITIES).json()["cities"]
    assert city["businesses_count"] == 1


def test_hierarchie_explorable_seulement_si_ville_active():
    pays, region, dep, maroua, _ = make_maroua_chain()
    region2 = make_zone("Nord", ZoneLevel.REGION, pays)
    dep2 = make_zone("Bénoué", ZoneLevel.DEPARTEMENT, region2)
    make_zone("Garoua", ZoneLevel.VILLE_VILLAGE, dep2)
    dep3 = make_zone("Logone-et-Chari", ZoneLevel.DEPARTEMENT, region)
    shop("A", zone=maroua)
    regions = by_name(connected().get(CITIES).json()["regions"])
    assert regions["Extrême-Nord"]["explorable"] is True
    assert regions["Nord"]["explorable"] is False
    deps = by_name(regions["Extrême-Nord"]["departements"])
    assert deps["Diamaré"]["explorable"] is True
    assert deps[dep3.name]["explorable"] is False
    assert by_name(regions["Nord"]["departements"])[dep2.name]["explorable"] is False


def test_profil_rattache_a_une_region_ne_figure_jamais():
    _, region, _, maroua, _ = make_maroua_chain()
    profile = shop("Orphelin", zone=maroua)
    # Contourne la validation du modèle : le cas ne doit jamais sortir sur la carte.
    BusinessProfile.objects.filter(pk=profile.pk).update(zone=region)
    data = connected().get(CITIES).json()
    assert data["cities"] == []
    assert all(not r["explorable"] for r in data["regions"])


def test_recherche_independante_de_la_regle_carte():
    _, region, _, maroua, _ = make_maroua_chain()
    profile = shop("Chez Riz", ["Riz"], zone=maroua)
    BusinessProfile.objects.filter(pk=profile.pk).update(zone=region)
    client = connected()
    assert client.get(CITIES).json()["cities"] == []  # la carte l'ignore…
    ids = [r["id"] for r in client.get("/api/search/", {"q": "riz"}).json()["results"]]
    assert ids == [profile.pk]  # …la recherche textuelle le trouve toujours.


def test_latitude_longitude_et_filtre_q():
    _, _, dep, maroua, _ = make_maroua_chain()
    maroua.latitude, maroua.longitude = 10.59, 14.32
    maroua.save()
    ebolowa = make_zone("Ébolowa", ZoneLevel.VILLE_VILLAGE, dep)
    shop("A", zone=maroua)
    shop("B", zone=ebolowa)
    client = connected()
    cities = by_name(client.get(CITIES).json()["cities"])
    assert cities["Maroua"]["latitude"] == 10.59 and cities["Maroua"]["longitude"] == 14.32
    assert cities["Ébolowa"]["latitude"] is None and cities["Ébolowa"]["longitude"] is None
    assert [c["name"] for c in client.get(CITIES, {"q": "EBOLO"}).json()["cities"]] == ["Ébolowa"]
    assert [c["name"] for c in client.get(CITIES, {"q": "mAr"}).json()["cities"]] == ["Maroua"]
    assert client.get(CITIES, {"q": "zzz"}).json()["cities"] == []


def test_quartiers_avec_compteurs():
    _, _, _, maroua, harde = make_maroua_chain()
    autre = make_zone("Doualaré", ZoneLevel.QUARTIER, maroua)
    make_zone("Vide", ZoneLevel.QUARTIER, maroua)
    a = shop("A", ["x", "y"], zone=harde)
    Offer.objects.create(profile=a, name="inactive", is_active=False)
    shop("B", ["z"], zone=harde)
    shop("C", zone=autre)
    shop("D", ["caché"], zone=harde, status=BusinessStatus.PENDING)
    shop("E", zone=maroua)
    response = connected().get(f"/api/map/cities/{maroua.pk}/areas/")
    assert response.status_code == 200
    data = response.json()
    assert data["city"] == {"id": maroua.pk, "name": "Maroua"}
    areas = by_name(data["areas"])
    assert set(areas) == {"Hardé", "Doualaré"}
    assert areas["Hardé"]["businesses_count"] == 2 and areas["Hardé"]["products_count"] == 3
    assert areas["Doualaré"]["businesses_count"] == 1 and areas["Doualaré"]["products_count"] == 0
    assert data["businesses_without_area"] == 1


def test_quartiers_404_si_ville_absente_de_la_carte():
    _, _, dep, maroua, harde = make_maroua_chain()
    vide = make_zone("Garoua", ZoneLevel.VILLE_VILLAGE, dep)
    client = connected()
    assert client.get(f"/api/map/cities/{vide.pk}/areas/").status_code == 404
    assert client.get(f"/api/map/cities/{dep.pk}/areas/").status_code == 404
    assert client.get(f"/api/map/cities/{harde.pk}/areas/").status_code == 404
    assert client.get("/api/map/cities/99999/areas/").status_code == 404


def test_commerces_du_quartier_pagines_sans_numero():
    _, _, _, maroua, harde = make_maroua_chain()
    for i in range(21):
        shop(f"Boutique {i:02d}", ["riz"], zone=harde)
    shop("Hors quartier", zone=maroua)
    shop("En attente", zone=harde, status=BusinessStatus.PENDING)
    client = connected()
    first = client.get(f"/api/map/areas/{harde.pk}/businesses/").json()
    assert first["count"] == 21 and len(first["results"]) == 20 and first["next"]
    second = client.get(f"/api/map/areas/{harde.pk}/businesses/", {"page": 2}).json()
    assert len(second["results"]) == 1
    item = first["results"][0]
    assert set(item) == {
        "id", "name", "kind", "secteur", "secteur_code", "zone", "repere",
        "description_activite", "photo", "prix_indicatif", "verifie",
    }
    assert item["zone"] == {"id": harde.pk, "name": "Hardé"}


def test_commerces_du_quartier_404():
    _, _, _, maroua, _ = make_maroua_chain()
    assert connected().get(f"/api/map/areas/{maroua.pk}/businesses/").status_code == 404
    assert connected().get("/api/map/areas/99999/businesses/").status_code == 404


def _walk(value):
    if isinstance(value, dict):
        for key, item in value.items():
            yield key
            yield from _walk(item)
    elif isinstance(value, list):
        for item in value:
            yield from _walk(item)
    elif isinstance(value, str):
        yield value


def test_aucun_numero_ni_piece_d_identite_dans_les_reponses():
    _, _, _, maroua, harde = make_maroua_chain()
    profile = provider("Dépanneur", zone=harde, cni_photo="prive/cni.jpg",
                       diplome_photo="prive/diplome.jpg")
    client = connected()
    responses = [
        client.get(CITIES),
        client.get(f"/api/map/cities/{maroua.pk}/areas/"),
        client.get(f"/api/map/areas/{harde.pk}/businesses/"),
    ]
    anchor = BusinessProfile.objects.get(pk=profile.pk).phone_anchor
    for response in responses:
        assert response.status_code == 200
        text = json.dumps(response.json())
        assert anchor not in text and "+237" not in text
        for token in _walk(response.json()):
            lowered = token.lower()
            assert "phone" not in lowered and "cni" not in lowered
            assert "diplome" not in lowered and "prive/" not in lowered


def test_nombre_de_requetes_borne():
    _, _, dep, maroua, harde = make_maroua_chain()

    def measure(path):
        client = connected()
        with CaptureQueriesContext(connection) as ctx:
            assert client.get(path).status_code == 200
        return len(ctx)

    def fill(n):
        for i in range(n):
            city = make_zone(f"Ville{n}{i}", ZoneLevel.VILLE_VILLAGE, dep)
            area = make_zone(f"Quartier{n}{i}", ZoneLevel.QUARTIER, city)
            shop(f"S{n}{i}", ["a"], zone=area)
            shop(f"T{n}{i}", ["a"], zone=harde)
            shop(f"U{n}{i}", zone=city)

    fill(2)
    paths = (
        CITIES, f"/api/map/cities/{maroua.pk}/areas/", f"/api/map/areas/{harde.pk}/businesses/"
    )
    before = [measure(p) for p in paths]
    fill(6)
    assert [measure(p) for p in paths] == before
