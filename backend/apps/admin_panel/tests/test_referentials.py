"""Référentiels modifiables par l'administration (T074b) : droits, CRUD, désactivation,
cohérence, audit, valeurs libres, nombre de requêtes."""
import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext

from apps.accounts.models import User
from apps.admin_panel.models import AuditAction, AuditLog
from apps.business.models import AccountType
from apps.catalog.models import CatalogProduct, Sector, Synonym
from apps.geo.models import Zone, ZoneLevel
from tests.factories.business_factory import (
    get_sector,
    get_service_category,
    get_structure_type,
    make_profile,
)
from tests.factories.catalog_factory import make_product, make_sector, make_subcategory
from tests.factories.zone_factory import make_maroua_chain, make_zone

from ._t074 import COMPLET, admin_in, api_as, check_permissions

pytestmark = pytest.mark.django_db

BASE = "/api/admin/referentials/"


@pytest.fixture
def admin():
    return admin_in(COMPLET)


@pytest.fixture
def client(admin):
    return api_as(admin)


def last_audit(action):
    return AuditLog.objects.filter(action=action).order_by("-id").first()


# --- Permissions : anonyme 401, simple / sans groupe / Validateur 403, complet OK ----


def test_permissions_liste_zones():
    check_permissions("get", BASE + "zones/", None, 200)


def test_permissions_creation_zone():
    make_zone("Cameroun", ZoneLevel.PAYS)
    check_permissions("post", BASE + "zones/", {"name": "Tchad", "level": "pays"}, 201)


def test_permissions_modification_zone():
    zone = make_zone("Cameroun", ZoneLevel.PAYS)
    check_permissions("patch", f"{BASE}zones/{zone.pk}/", {"name": "Cameroun 2"}, 200)


def test_permissions_desactivation_zone():
    zone = make_zone("Cameroun", ZoneLevel.PAYS)
    check_permissions("post", f"{BASE}zones/{zone.pk}/deactivate/", {}, 200)


def test_permissions_valeurs_libres():
    check_permissions("get", BASE + "free-values/", None, 200)


@pytest.mark.parametrize("slug", ["sectors", "subcategories", "service-categories",
                                  "structure-types", "products", "synonyms"])
def test_permissions_listes(slug):
    check_permissions("get", f"{BASE}{slug}/", None, 200)


def test_la_permission_est_reservee_a_l_administrateur_complet():
    from django.contrib.auth.models import Group
    codes = lambda n: set(  # noqa: E731
        Group.objects.get(name=n).permissions.values_list("codename", flat=True))
    assert "peut_gerer_referentiels" in codes("Administrateur complet")
    assert "peut_gerer_referentiels" not in codes("Validateur")


# --- Zones : création et cohérence --------------------------------------------------


def test_creation_zone_audit_et_chemin_valide(client, admin):
    pays = make_zone("Cameroun", ZoneLevel.PAYS)
    response = client.post(
        BASE + "zones/", {"name": "Adamaoua", "level": "region", "parent": pays.pk,
                          "order": 3, "latitude": 7.3, "longitude": 13.5}, format="json")
    assert response.status_code == 201, response.content
    body = response.json()
    assert (body["name"], body["level"], body["parent"], body["is_active"]) == (
        "Adamaoua", "region", pays.pk, True)
    zone = Zone.objects.get(pk=body["id"])
    assert zone.normalized_name == "adamaoua"
    log = last_audit(AuditAction.CREATION_REFERENTIEL)
    assert log.admin == admin and log.target_type == "geo.zone" and log.target_id == zone.pk
    assert "Adamaoua" in log.reason


def test_nouveau_departement_sans_nouvelle_version(client):
    """Le découpage administratif change par l'API : un département et une ville de plus."""
    _pays, region, *_ = make_maroua_chain()
    dep = client.post(BASE + "zones/", {"name": "Mayo-Danay", "level": "departement",
                                        "parent": region.pk}, format="json")
    assert dep.status_code == 201
    ville = client.post(BASE + "zones/", {"name": "Yagoua", "level": "ville_village",
                                          "parent": dep.json()["id"]}, format="json")
    assert ville.status_code == 201
    public = client.get("/api/zones/", {"parent": dep.json()["id"]}).json()["results"]
    assert [z["name"] for z in public] == ["Yagoua"]


def test_parent_du_mauvais_niveau_refuse(client):
    pays, region, *_ = make_maroua_chain()
    # un quartier directement sous une région
    response = client.post(BASE + "zones/", {"name": "Hors-sol", "level": "quartier",
                                             "parent": region.pk}, format="json")
    assert response.status_code == 400
    assert "parent" in response.json()["fields"]
    # une région sans parent
    assert client.post(BASE + "zones/", {"name": "Orpheline", "level": "region"},
                       format="json").status_code == 400
    # un pays avec un parent
    assert client.post(BASE + "zones/", {"name": "Autre pays", "level": "pays",
                                         "parent": pays.pk}, format="json").status_code == 400
    assert not Zone.objects.filter(name__in=["Hors-sol", "Orpheline", "Autre pays"]).exists()


def test_pas_de_cycle_ni_de_parent_soi_meme(client):
    pays, region, departement, ville, _ = make_maroua_chain()
    assert client.patch(f"{BASE}zones/{region.pk}/", {"parent": region.pk},
                        format="json").status_code == 400
    # le pays sous l'un de ses descendants
    assert client.patch(f"{BASE}zones/{pays.pk}/", {"parent": ville.pk},
                        format="json").status_code == 400
    # la région sous son propre département
    assert client.patch(f"{BASE}zones/{region.pk}/", {"parent": departement.pk},
                        format="json").status_code == 400
    region.refresh_from_db()
    assert region.parent_id == pays.pk


def test_nom_unique_sous_le_meme_parent_sans_accent_ni_casse(client):
    pays, region, *_ = make_maroua_chain()
    response = client.post(BASE + "zones/", {"name": "EXTREME-nord", "level": "region",
                                             "parent": pays.pk}, format="json")
    assert response.status_code == 409 and response.json()["code"] == "already_exists"
    # même nom sous un autre parent : accepté
    autre = make_zone("Tchad", ZoneLevel.PAYS)
    assert client.post(BASE + "zones/", {"name": "Extrême-Nord", "level": "region",
                                         "parent": autre.pk}, format="json").status_code == 201


def test_modification_audit_ancienne_nouvelle_valeur_et_niveau_fixe(client, admin):
    _p, region, *_ = make_maroua_chain()
    response = client.patch(f"{BASE}zones/{region.pk}/",
                            {"name": "Extrême Nord", "order": 5, "level": "pays"}, format="json")
    assert response.status_code == 200
    region.refresh_from_db()
    assert (region.name, region.order, region.level) == ("Extrême Nord", 5, "region")
    log = last_audit(AuditAction.MODIFICATION_REFERENTIEL)
    assert log.admin == admin and log.target_id == region.pk
    assert "'Extrême-Nord' -> 'Extrême Nord'" in log.reason and "0 -> 5" in log.reason
    # sans changement : aucun audit de plus
    before = AuditLog.objects.count()
    assert client.patch(f"{BASE}zones/{region.pk}/", {"order": 5}, format="json").status_code == 200
    assert AuditLog.objects.count() == before


def test_zone_inconnue_404_et_pas_de_delete(client):
    assert client.get(f"{BASE}zones/999999/").status_code == 404
    zone = make_zone("Cameroun", ZoneLevel.PAYS)
    assert client.delete(f"{BASE}zones/{zone.pk}/").status_code == 405
    assert Zone.objects.filter(pk=zone.pk).exists()


# --- Désactivation / réactivation ---------------------------------------------------


def test_desactiver_une_zone_la_retire_des_choix_publics_puis_la_reactiver(client, admin):
    *_, ville, quartier = make_maroua_chain()
    public = lambda: {z["id"] for z in client.get(  # noqa: E731
        "/api/zones/", {"level": "quartier"}).json()["results"]}
    assert quartier.pk in public()
    response = client.post(f"{BASE}zones/{quartier.pk}/deactivate/", {"reason": "doublon"},
                           format="json")
    assert response.status_code == 200 and response.json()["is_active"] is False
    quartier.refresh_from_db()
    assert quartier.is_active is False and Zone.objects.filter(pk=quartier.pk).exists()
    assert quartier.pk not in public()
    log = last_audit(AuditAction.DESACTIVATION_REFERENTIEL)
    assert log.admin == admin and "True -> False" in log.reason and "doublon" in log.reason
    # état déjà atteint
    again = client.post(f"{BASE}zones/{quartier.pk}/deactivate/", {}, format="json")
    assert again.status_code == 409 and again.json()["code"] == "invalid_state"
    back = client.post(f"{BASE}zones/{quartier.pk}/reactivate/", {}, format="json")
    assert back.status_code == 200 and back.json()["is_active"] is True
    assert quartier.pk in public()
    assert last_audit(AuditAction.REACTIVATION_REFERENTIEL).target_id == quartier.pk


def test_pas_de_desactivation_d_un_parent_avec_enfants_actifs(client):
    _p, region, departement, ville, quartier = make_maroua_chain()
    response = client.post(f"{BASE}zones/{ville.pk}/deactivate/", {}, format="json")
    assert response.status_code == 409 and response.json()["code"] == "has_active_children"
    ville.refresh_from_db()
    assert ville.is_active is True
    # on désactive d'abord l'enfant, ensuite le parent est possible
    assert client.post(f"{BASE}zones/{quartier.pk}/deactivate/", {}, format="json"
                       ).status_code == 200
    assert client.post(f"{BASE}zones/{ville.pk}/deactivate/", {}, format="json"
                       ).status_code == 200


def test_pas_d_enfant_ni_de_reactivation_sous_un_parent_desactive(client):
    _p, region, departement, ville, quartier = make_maroua_chain()
    client.post(f"{BASE}zones/{quartier.pk}/deactivate/", {}, format="json")
    client.post(f"{BASE}zones/{ville.pk}/deactivate/", {}, format="json")
    created = client.post(BASE + "zones/", {"name": "Domayo", "level": "quartier",
                                            "parent": ville.pk}, format="json")
    assert created.status_code == 409 and created.json()["code"] == "parent_inactive"
    reactivated = client.post(f"{BASE}zones/{quartier.pk}/reactivate/", {}, format="json")
    assert reactivated.status_code == 409 and reactivated.json()["code"] == "parent_inactive"
    assert Zone.objects.get(pk=quartier.pk).is_active is False


def test_zone_desactivee_disparait_de_la_carte(client):
    from apps.business.models import BusinessStatus
    from tests.factories.business_factory import get_or_make_zone
    quartier = get_or_make_zone(ZoneLevel.QUARTIER)
    ville = quartier.parent
    make_profile(zone=quartier, status=BusinessStatus.ACTIVE)
    cities = lambda: {c["id"] for c in client.get("/api/map/cities/").json()["cities"]}  # noqa: E731
    assert ville.pk in cities()
    assert client.get(f"/api/map/cities/{ville.pk}/areas/").status_code == 200
    client.post(f"{BASE}zones/{quartier.pk}/deactivate/", {}, format="json")
    assert ville.pk not in cities()  # plus aucun commerce visible dans une zone active
    client.post(f"{BASE}zones/{ville.pk}/deactivate/", {}, format="json")
    assert client.get(f"/api/map/cities/{ville.pk}/areas/").status_code == 404


# --- Secteurs, sous-catégories, catégories, types ------------------------------------


def test_secteur_creation_code_stable_et_doublon(client):
    response = client.post(BASE + "sectors/", {"code": "agriculture", "name": "Agriculture",
                                               "icon": "🌾"}, format="json")
    assert response.status_code == 201 and response.json()["code"] == "agriculture"
    dup = client.post(BASE + "sectors/", {"code": "agriculture", "name": "Autre"}, format="json")
    assert dup.status_code == 409 and dup.json()["code"] == "already_exists"
    bad = client.post(BASE + "sectors/", {"code": "Mauvais Code", "name": "X"}, format="json")
    assert bad.status_code == 400 and "code" in bad.json()["fields"]
    # le code ne change pas par PATCH
    sector_id = response.json()["id"]
    client.patch(f"{BASE}sectors/{sector_id}/", {"code": "autre_code", "name": "Agri"},
                 format="json")
    sector = Sector.objects.get(pk=sector_id)
    assert (sector.code, sector.name) == ("agriculture", "Agri")


def test_secteur_avec_sous_categories_actives_non_desactivable(client):
    sector = make_sector()
    sub = make_subcategory(sector)
    response = client.post(f"{BASE}sectors/{sector.pk}/deactivate/", {}, format="json")
    assert response.status_code == 409 and response.json()["code"] == "has_active_children"
    assert client.post(f"{BASE}subcategories/{sub.pk}/deactivate/", {}, format="json"
                       ).status_code == 200
    assert client.post(f"{BASE}sectors/{sector.pk}/deactivate/", {}, format="json"
                       ).status_code == 200
    sector.refresh_from_db()
    assert sector.is_active is False
    public = client.get("/api/referentials/sectors/").json()
    assert sector.code not in {r["code"] for r in public}
    # la sous-catégorie ne peut pas être réactivée sous un secteur désactivé
    reactivate = client.post(f"{BASE}subcategories/{sub.pk}/reactivate/", {}, format="json")
    assert reactivate.status_code == 409 and reactivate.json()["code"] == "parent_inactive"
    created = client.post(BASE + "subcategories/", {"sector": sector.pk, "code": "legumes",
                                                    "name": "Légumes"}, format="json")
    assert created.status_code == 409 and created.json()["code"] == "parent_inactive"


def test_sous_categorie_creation_et_unicite_du_code_dans_le_secteur(client):
    sector = make_sector()
    body = {"sector": sector.pk, "code": "fruits", "name": "Fruits"}
    assert client.post(BASE + "subcategories/", body, format="json").status_code == 201
    assert client.post(BASE + "subcategories/", body, format="json").status_code == 409
    other = make_sector(code="mode", name="Mode")
    assert client.post(BASE + "subcategories/", {**body, "sector": other.pk},
                       format="json").status_code == 201
    listing = client.get(BASE + "subcategories/", {"sector": sector.pk}).json()
    assert [r["code"] for r in listing["results"]] == ["fruits"]


@pytest.mark.parametrize("slug,model_code", [
    ("sectors", "autre"), ("service-categories", "autre"), ("structure-types", "autre")])
def test_la_ligne_autre_est_protegee(client, slug, model_code):
    from apps.catalog.models import ServiceCategory, StructureType
    model = {"sectors": Sector, "service-categories": ServiceCategory,
             "structure-types": StructureType}[slug]
    item = model.objects.create(code=model_code, name="Autre")
    response = client.post(f"{BASE}{slug}/{item.pk}/deactivate/", {}, format="json")
    assert response.status_code == 409 and response.json()["code"] == "protected_item"
    item.refresh_from_db()
    assert item.is_active is True


def test_categories_de_service_et_types_de_structure_crud_et_desactivation(client):
    for slug, code in (("service-categories", "jardinage"), ("structure-types", "ecole")):
        created = client.post(f"{BASE}{slug}/", {"code": code, "name": code.title()},
                              format="json")
        assert created.status_code == 201
        pk = created.json()["id"]
        assert client.patch(f"{BASE}{slug}/{pk}/", {"name": "Renommé"}, format="json"
                            ).json()["name"] == "Renommé"
        off = client.post(f"{BASE}{slug}/{pk}/deactivate/", {}, format="json")
        assert off.status_code == 200 and off.json()["is_active"] is False
        assert client.get(f"{BASE}{slug}/", {"is_active": "false"}).json()["count"] == 1
        assert client.get(f"{BASE}{slug}/", {"is_active": "true"}).json()["count"] == 0


# --- Produits et synonymes ----------------------------------------------------------


def test_produit_creation_doublon_normalise_modification_et_desactivation(client):
    sub = make_subcategory(make_sector())
    created = client.post(BASE + "products/", {"name": "Banane plantain", "category": sub.pk},
                          format="json")
    assert created.status_code == 201
    pk = created.json()["id"]
    assert created.json()["category_name"] == "Fruits" and created.json()["synonyms_count"] == 0
    dup = client.post(BASE + "products/", {"name": "BANANE  plantain"}, format="json")
    assert dup.status_code == 409
    client.patch(f"{BASE}products/{pk}/", {"name": "Banane douce"}, format="json")
    assert CatalogProduct.objects.get(pk=pk).normalized_name == "banane douce"
    off = client.post(f"{BASE}products/{pk}/deactivate/", {}, format="json")
    assert off.status_code == 200
    assert CatalogProduct.objects.filter(pk=pk, is_active=False).exists()
    assert last_audit(AuditAction.DESACTIVATION_REFERENTIEL).target_type == "catalog.catalogproduct"


def test_synonymes_crud_sans_suppression(client):
    product = make_product("Banane")
    created = client.post(BASE + "synonyms/", {"product": product.pk, "term": "Bananes"},
                          format="json")
    assert created.status_code == 201 and created.json()["product_name"] == "Banane"
    pk = created.json()["id"]
    assert client.post(BASE + "synonyms/", {"product": product.pk, "term": "bananes"},
                       format="json").status_code == 409
    assert client.patch(f"{BASE}synonyms/{pk}/", {"term": "Dessert"}, format="json"
                        ).status_code == 200
    assert Synonym.objects.get(pk=pk).normalized_term == "dessert"
    assert client.delete(f"{BASE}synonyms/{pk}/").status_code == 405
    assert Synonym.objects.get(pk=pk).is_active is True
    off = client.post(f"{BASE}synonyms/{pk}/deactivate/", {}, format="json")
    assert off.status_code == 200 and off.json()["is_active"] is False
    assert client.post(f"{BASE}synonyms/{pk}/deactivate/", {}, format="json"
                       ).json()["code"] == "invalid_state"
    assert last_audit(AuditAction.DESACTIVATION_REFERENTIEL).target_type == "catalog.synonym"
    listed = client.get(BASE + "synonyms/", {"is_active": "false"}).json()["results"]
    assert [row["id"] for row in listed] == [pk]
    assert client.get(BASE + "synonyms/", {"is_active": "true"}).json()["results"] == []
    on = client.post(f"{BASE}synonyms/{pk}/reactivate/", {}, format="json")
    assert on.status_code == 200 and on.json()["is_active"] is True
    assert last_audit(AuditAction.REACTIVATION_REFERENTIEL).target_type == "catalog.synonym"
    assert Synonym.objects.filter(pk=pk).exists()


def test_synonymes_desactivation_droits(client):
    product = make_product("Banane")
    syn = Synonym.objects.create(product=product, term="Dessert")
    check_permissions("post", f"{BASE}synonyms/{syn.pk}/deactivate/", {}, 200)
    check_permissions("post", f"{BASE}synonyms/{syn.pk}/reactivate/", {}, 200)


# --- Valeurs libres à examiner -------------------------------------------------------


def _free_profiles():
    autre_sector = get_sector("autre", "Autre")
    autre_service = get_service_category("autre", "Autre")
    autre_struct = get_structure_type("autre", "Autre")
    for label in ("Quincaillerie", "quincaillerie ", "QUINCAILLERIE", "Boulangerie", "Élevage",
                  "elevage"):
        make_profile(secteur=autre_sector, secteur_libre=label)
    make_profile(AccountType.PRESTATAIRE_SERVICE, categorie_service=autre_service,
                 categorie_service_libre="Dressage")
    make_profile(AccountType.STRUCTURE, structure_type=autre_struct,
                 structure_type_libre="Crèche")


def test_valeurs_libres_regroupees_triees_et_sans_donnee_personnelle(client):
    _free_profiles()
    response = client.get(BASE + "free-values/")
    assert response.status_code == 200
    data = response.json()
    sectors = data["secteur_libre"]
    assert [(r["normalized"], r["count"]) for r in sectors] == [
        ("quincaillerie", 3), ("elevage", 2), ("boulangerie", 1)]
    assert sectors[0]["value"] in {"Quincaillerie", "QUINCAILLERIE"}
    assert data["categorie_service_libre"] == [
        {"value": "Dressage", "normalized": "dressage", "count": 1}]
    assert data["structure_type_libre"][0]["normalized"] == "creche"
    text = response.content.decode()
    assert "+237" not in text and "phone" not in text and "owner" not in text


def test_valeurs_libres_excluent_comptes_bloques_et_supprimes(client):
    autre = get_sector("autre", "Autre")
    make_profile(secteur=autre, secteur_libre="Visible")
    bloque = make_profile(secteur=autre, secteur_libre="Cachée bloquée")
    supprime = make_profile(secteur=autre, secteur_libre="Cachée supprimée")
    User.objects.filter(pk=bloque.owner_id).update(is_blocked=True)
    User.objects.filter(pk=supprime.owner_id).update(is_deleted=True)
    values = [r["normalized"] for r in client.get(BASE + "free-values/").json()["secteur_libre"]]
    assert values == ["visible"]


# --- Nombre de requêtes -------------------------------------------------------------


def _queries(client, url):
    with CaptureQueriesContext(connection) as ctx:
        assert client.get(url).status_code == 200
    return len(ctx)


def test_listes_sans_n_plus_un(client):
    pays = make_zone("Cameroun", ZoneLevel.PAYS)
    sector = make_sector()
    sub = make_subcategory(sector)
    for i in range(3):
        make_zone(f"Région {i}", ZoneLevel.REGION, pays)
        make_product(f"Produit {i}", sub, synonyms=[f"syn {i}"])
    first = {u: _queries(client, BASE + u) for u in ("zones/", "products/", "synonyms/",
                                                     "sectors/", "subcategories/")}
    for i in range(3, 15):
        make_zone(f"Région {i}", ZoneLevel.REGION, pays)
        make_product(f"Produit {i}", sub, synonyms=[f"syn {i}"])
        make_subcategory(sector, code=f"sous_{i}", name=f"Sous {i}")
    second = {u: _queries(client, BASE + u) for u in first}
    assert second == first
    assert max(second.values()) <= 12
