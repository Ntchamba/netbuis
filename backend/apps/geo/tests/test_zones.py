"""Zones (T020) : hiérarchie, chargement idempotent du CSV, API publique, admin."""
from io import StringIO

import pytest
from django.core.exceptions import ValidationError
from django.core.management import call_command
from django.core.management.base import CommandError
from django.db import IntegrityError, transaction
from rest_framework.test import APIClient

from apps.geo.models import Zone, ZoneLevel
from tests.factories.zone_factory import make_maroua_chain, make_zone

pytestmark = pytest.mark.django_db

HEADER = "level,name,parent_level,parent_name,order,official_code,latitude,longitude\n"


def load(tmp_path, body, name="z.csv"):
    path = tmp_path / name
    path.write_text(HEADER + body, encoding="utf-8")
    out = StringIO()
    call_command("load_zones", file=str(path), stdout=out)
    return out.getvalue()


# --- Hiérarchie -----------------------------------------------------------------------


def test_nom_normalise_sans_accents_minuscule():
    zone = make_zone("Extrême-Nord", ZoneLevel.PAYS)
    assert zone.normalized_name == "extreme nord"


def test_ville_rattachee_a_un_departement_valide():
    _, _, departement, ville, quartier = make_maroua_chain()
    assert ville.parent == departement
    assert quartier.parent == ville


def test_ville_rattachee_a_un_arrondissement_valide():
    _, _, departement, _, _ = make_maroua_chain()
    arr = make_zone("Maroua 1", ZoneLevel.ARRONDISSEMENT, departement)
    ville = make_zone("Autre ville", ZoneLevel.VILLE_VILLAGE, arr)
    assert ville.parent == arr


def test_quartier_rattache_a_un_departement_refuse():
    _, _, departement, _, _ = make_maroua_chain()
    with pytest.raises(ValidationError) as exc:
        make_zone("Nulle part", ZoneLevel.QUARTIER, departement)
    assert "parent" in exc.value.message_dict


def test_parent_de_niveau_inferieur_refuse():
    _, _, _, _, quartier = make_maroua_chain()
    with pytest.raises(ValidationError):
        make_zone("Région sous un quartier", ZoneLevel.REGION, quartier)


def test_pays_avec_parent_et_region_sans_parent_refuses():
    pays, *_ = make_maroua_chain()
    with pytest.raises(ValidationError):
        make_zone("Autre pays", ZoneLevel.PAYS, pays)
    with pytest.raises(ValidationError):
        make_zone("Région orpheline", ZoneLevel.REGION)


def test_zone_parent_d_elle_meme_refusee():
    pays, region, *_ = make_maroua_chain()
    region.parent = region
    with pytest.raises(ValidationError):
        region.save()
    with pytest.raises(ValidationError):
        region.clean()


def test_cycle_refuse():
    pays, region, *_ = make_maroua_chain()
    pays.parent = region
    with pytest.raises(ValidationError):
        pays.save()


def test_coordonnees_facultatives_et_bornees():
    pays = make_zone("Cameroun", ZoneLevel.PAYS)
    assert pays.latitude is None and pays.longitude is None
    region = make_zone("Nord", ZoneLevel.REGION, pays, latitude=10.5, longitude=14.3)
    assert region.latitude == 10.5
    with pytest.raises(ValidationError):
        make_zone("Sud", ZoneLevel.REGION, pays, latitude=120)


def test_doublon_refuse_en_base_meme_sans_parent():
    make_zone("Cameroun", ZoneLevel.PAYS)
    with pytest.raises(ValidationError):
        make_zone("cameroun", ZoneLevel.PAYS)
    with pytest.raises(IntegrityError), transaction.atomic():
        Zone.objects.bulk_create(
            [Zone(name="Cameroun", normalized_name="cameroun", level=ZoneLevel.PAYS)]
        )


def test_chemin_du_pays_a_la_zone():
    pays, region, departement, ville, quartier = make_maroua_chain()
    assert quartier.get_path() == [pays, region, departement, ville, quartier]


# --- load_zones -----------------------------------------------------------------------


def test_load_zones_idempotent(tmp_path):
    body = "pays,Cameroun,,,1,,,\nregion,Nord,pays,Cameroun,1,,,\n"
    assert "2 créées, 0 mises à jour, 0 inchangées" in load(tmp_path, body)
    assert "0 créées, 0 mises à jour, 2 inchangées" in load(tmp_path, body)
    assert Zone.objects.count() == 2


def test_load_zones_met_a_jour_sans_doublon(tmp_path):
    load(tmp_path, "pays,Cameroun,,,1,,,\nregion,Nord,pays,Cameroun,1,,,\n")
    out = load(tmp_path, "pays,Cameroun,,,1,,,\nregion,NORD,pays,cameroun,5,R7,10.5,14.2\n")
    assert "1 mises à jour" in out and "1 inchangées" in out
    nord = Zone.objects.get(level="region")
    assert (nord.name, nord.order, nord.official_code, nord.latitude) == ("NORD", 5, "R7", 10.5)
    assert Zone.objects.count() == 2


def test_load_zones_parent_introuvable_refuse_avec_numero_de_ligne(tmp_path):
    with pytest.raises(CommandError) as exc:
        load(tmp_path, "pays,Cameroun,,,1,,,\nregion,Nord,pays,Gabon,1,,,\n")
    assert "Ligne 3" in str(exc.value) and "introuvable" in str(exc.value)
    assert Zone.objects.count() == 0  # tout est annulé


def test_load_zones_niveau_de_parent_non_superieur_refuse(tmp_path):
    body = "pays,Cameroun,,,1,,,\nregion,Nord,pays,Cameroun,1,,,\nquartier,Q,region,Nord,1,,,\n"
    with pytest.raises(CommandError) as exc:
        load(tmp_path, body)
    assert "Ligne 4" in str(exc.value)


def test_load_zones_colonnes_manquantes(tmp_path):
    path = tmp_path / "x.csv"
    path.write_text("level,name\npays,X\n", encoding="utf-8")
    with pytest.raises(CommandError):
        call_command("load_zones", file=str(path))


def test_fichier_de_depart():
    call_command("load_zones", stdout=StringIO())
    count = Zone.objects.count()
    call_command("load_zones", stdout=StringIO())
    assert Zone.objects.count() == count
    assert Zone.objects.filter(level="pays").get().name == "Cameroun"
    assert Zone.objects.filter(level="region").count() == 10
    diamare = Zone.objects.get(level="departement", name="Diamaré")
    assert diamare.parent.name == "Extrême-Nord"
    assert set(Zone.objects.filter(parent=diamare, level="arrondissement").values_list(
        "name", flat=True)) == {"Maroua 1", "Maroua 2", "Maroua 3"}
    maroua = Zone.objects.get(level="ville_village", name="Maroua")
    assert maroua.parent == diamare
    assert set(maroua.children.values_list("name", flat=True)) == {
        "Hardé", "Dougoï", "Domayo", "Djarengol"}
    assert not Zone.objects.exclude(latitude=None).exists()
    assert not Zone.objects.exclude(official_code="").exists()


# --- API ------------------------------------------------------------------------------


@pytest.fixture
def api():
    return APIClient()


def test_liste_publique_sans_authentification(api):
    pays, *_ = make_maroua_chain()
    resp = api.get("/api/zones/")
    assert resp.status_code == 200
    assert resp.json()["count"] == 5
    assert set(resp.json()["results"][0]) == {
        "id", "name", "level", "parent", "official_code", "order", "latitude", "longitude"}


def test_filtre_level_et_parent(api):
    pays, region, departement, ville, quartier = make_maroua_chain()
    make_zone("Hardé 2", ZoneLevel.QUARTIER, ville)
    res = api.get("/api/zones/", {"level": "quartier", "parent": ville.id}).json()
    assert {z["name"] for z in res["results"]} == {"Hardé", "Hardé 2"}
    res = api.get("/api/zones/", {"parent": pays.id}).json()
    assert [z["name"] for z in res["results"]] == ["Extrême-Nord"]
    res = api.get("/api/zones/", {"level": "pays"}).json()
    assert [z["id"] for z in res["results"]] == [pays.id]


def test_tri_par_ordre_puis_nom(api):
    pays = make_zone("Cameroun", ZoneLevel.PAYS)
    make_zone("Sud", ZoneLevel.REGION, pays, order=2)
    make_zone("Est", ZoneLevel.REGION, pays, order=2)
    make_zone("Ouest", ZoneLevel.REGION, pays, order=1)
    names = [z["name"] for z in api.get("/api/zones/", {"level": "region"}).json()["results"]]
    assert names == ["Ouest", "Est", "Sud"]


def test_zones_inactives_cachees(api):
    pays, region, *_ = make_maroua_chain()
    region.is_active = False
    region.save()
    assert api.get("/api/zones/", {"parent": pays.id}).json()["count"] == 0
    assert api.get(f"/api/zones/{region.id}/").status_code == 404


def test_level_inconnu_400(api):
    resp = api.get("/api/zones/", {"level": "planete"})
    assert resp.status_code == 400
    assert resp.json()["code"] == "invalid" and "level" in resp.json()["fields"]


def test_parent_mal_forme_400_et_inexistant_liste_vide(api):
    assert api.get("/api/zones/", {"parent": "abc"}).status_code == 400
    resp = api.get("/api/zones/", {"parent": 999999})
    assert resp.status_code == 200 and resp.json()["results"] == []


def test_detail_avec_chemin(api):
    pays, region, departement, ville, quartier = make_maroua_chain()
    resp = api.get(f"/api/zones/{quartier.id}/")
    assert resp.status_code == 200
    body = resp.json()
    assert body["name"] == "Hardé" and body["parent"] == ville.id
    assert body["path"] == [
        {"id": z.id, "name": z.name, "level": z.level}
        for z in (pays, region, departement, ville, quartier)
    ]


def test_detail_inconnu_404(api):
    resp = api.get("/api/zones/999999/")
    assert resp.status_code == 404 and resp.json()["code"] == "not_found"


def test_ecriture_interdite_par_l_api(api):
    assert api.post("/api/zones/", {"name": "X"}).status_code in (401, 403, 405)


# --- Admin ----------------------------------------------------------------------------


@pytest.fixture
def admin_browser():
    from django.test import Client

    from tests.factories.user_factory import UserFactory

    user = UserFactory(is_admin=True, is_staff=True, is_superuser=True)
    client = Client()
    client.force_login(user)
    return client


def test_admin_liste_et_edition(admin_browser):
    _, region, *_ = make_maroua_chain()
    assert admin_browser.get("/django-admin/geo/zone/").status_code == 200
    assert admin_browser.get(f"/django-admin/geo/zone/{region.id}/change/").status_code == 200


def test_admin_applique_la_validation_du_modele(admin_browser):
    pays, region, _, _, quartier = make_maroua_chain()
    data = {"name": "Extrême-Nord", "level": "region", "parent": quartier.id,
            "official_code": "", "order": 1, "is_active": "on"}
    resp = admin_browser.post(f"/django-admin/geo/zone/{region.id}/change/", data)
    assert resp.status_code == 200  # formulaire renvoyé avec l'erreur
    region.refresh_from_db()
    assert region.parent == pays
    data["parent"] = pays.id
    data["name"] = "Extrême-Nord (modifié)"
    resp = admin_browser.post(f"/django-admin/geo/zone/{region.id}/change/", data)
    assert resp.status_code == 302
    region.refresh_from_db()
    assert region.name == "Extrême-Nord (modifié)"
