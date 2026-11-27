"""Routes publiques des référentiels et du catalogue (T021) + admin Django."""
from io import StringIO

import pytest
from django.core.management import call_command
from rest_framework.test import APIClient

from apps.catalog.models import Sector, ServiceCategory, StructureType
from tests.factories.catalog_factory import make_product, make_sector, make_subcategory

pytestmark = pytest.mark.django_db


@pytest.fixture
def api():
    return APIClient()


@pytest.fixture
def seeded():
    call_command("seed_referentials", stdout=StringIO())


# --- Secteurs -------------------------------------------------------------------------


def test_secteurs_publics_avec_sous_categories(api, seeded):
    resp = api.get("/api/referentials/sectors/")
    assert resp.status_code == 200
    body = resp.json()
    assert isinstance(body, list) and len(body) == 10  # tableau simple, sans pagination
    first = body[0]
    assert set(first) == {"id", "code", "name", "icon", "order", "subcategories"}
    assert (first["code"], first["name"], first["icon"]) == ("alimentation", "Alimentation", "🍌")
    assert len(first["subcategories"]) == 12
    assert set(first["subcategories"][0]) == {"id", "code", "name", "icon", "order"}
    assert first["subcategories"][-1]["name"] == "Autre"
    assert body[-1]["name"] == "Autre" and len(body[-1]["subcategories"]) == 1


def test_secteurs_sans_jeton_meme_avec_un_jeton_invalide(api, seeded):
    api.credentials(HTTP_AUTHORIZATION="Bearer nimporte.quoi")
    assert api.get("/api/referentials/sectors/").status_code == 200


def test_secteurs_inactifs_et_sous_categories_inactives_cachees(api):
    a = make_sector("a", "A", order=2)
    b = make_sector("b", "B", order=1)
    make_sector("c", "C", order=3, is_active=False)
    make_subcategory(a, "x", "X2", order=2)
    make_subcategory(a, "y", "X1", order=1)
    make_subcategory(a, "z", "Cachée", is_active=False)
    body = api.get("/api/referentials/sectors/").json()
    assert [s["code"] for s in body] == [b.code, a.code]
    assert [s["name"] for s in body[1]["subcategories"]] == ["X1", "X2"]
    assert body[0]["subcategories"] == []


def test_tri_par_ordre_puis_nom(api):
    make_sector("b", "Beta", order=1)
    make_sector("a", "Alpha", order=1)
    make_sector("c", "Gamma", order=0)
    assert [s["name"] for s in api.get("/api/referentials/sectors/").json()] == [
        "Gamma", "Alpha", "Beta"
    ]


def test_secteurs_nombre_de_requetes_constant(api, seeded, django_assert_max_num_queries):
    with django_assert_max_num_queries(3):
        api.get("/api/referentials/sectors/")


# --- Catégories de service et types de structure --------------------------------------


def test_categories_de_service(api, seeded):
    resp = api.get("/api/referentials/service-categories/")
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) == 7 and set(body[0]) == {"id", "code", "name", "icon", "order"}
    assert body[0]["name"] == "Enseignement à domicile" and body[-1]["name"] == "Autre"


def test_types_de_structure(api, seeded):
    resp = api.get("/api/referentials/structure-types/")
    assert resp.status_code == 200
    body = resp.json()
    assert [(t["code"], t["icon"]) for t in body] == [
        ("supermarche", "🛒"), ("restaurant", "🍲"), ("hotel", "🏨"), ("sante", "🏥"),
        ("autre", "✨"),
    ]


def test_lignes_inactives_cachees_pour_service_et_structure(api, seeded):
    ServiceCategory.objects.filter(code="evenementiel").update(is_active=False)
    StructureType.objects.filter(code="hotel").update(is_active=False)
    assert len(api.get("/api/referentials/service-categories/").json()) == 6
    assert len(api.get("/api/referentials/structure-types/").json()) == 4


@pytest.mark.parametrize(
    "url",
    [
        "/api/referentials/sectors/",
        "/api/referentials/service-categories/",
        "/api/referentials/structure-types/",
        "/api/catalog/products/",
    ],
)
def test_ecriture_interdite_par_l_api(api, url):
    assert api.post(url, {"name": "X"}).status_code in (401, 403, 405)
    assert api.delete(url).status_code in (401, 403, 405)


# --- Recherche de produits ------------------------------------------------------------


def search(api, q):
    return api.get("/api/catalog/products/", {"q": q})


def test_recherche_prefixe_insensible_a_la_casse_et_aux_accents(api):
    make_product("Épinards")
    make_product("Plantain")
    for q in ("epi", "ÉPI", "Épin", "  epinards "):
        resp = search(api, q)
        assert resp.status_code == 200
        assert [p["name"] for p in resp.json()] == ["Épinards"], q


def test_prefixe_avant_contient_puis_alphabetique(api):
    make_product("Gros piment")
    make_product("Piment doux")
    make_product("Piment")
    assert [p["name"] for p in search(api, "piment").json()] == [
        "Piment", "Piment doux", "Gros piment"
    ]


def test_produit_trouve_par_un_synonyme_renvoye_une_fois(api):
    make_product("Riz", synonyms=["Rice", "Riz blanc"])
    make_product("Rizière jouet")
    body = search(api, "ric").json()
    assert [p["name"] for p in body] == ["Riz"]
    # « Riz » correspond par son nom et par un synonyme : il n'apparaît qu'une fois.
    assert [p["name"] for p in search(api, "riz").json()] == ["Riz", "Rizière jouet"]


def test_synonyme_prefixe_avant_nom_qui_contient(api):
    make_product("Gombo frais")
    make_product("Légume vert", synonyms=["fraisier"])
    assert [p["name"] for p in search(api, "frais").json()] == ["Légume vert", "Gombo frais"]


def test_synonyme_contient(api):
    make_product("Mangue", synonyms=["fruit tropical"])
    assert [p["name"] for p in search(api, "tropic").json()] == ["Mangue"]


def test_dix_resultats_au_maximum(api):
    for i in range(15):
        make_product(f"Tomate {i:02d}")
    body = search(api, "tomate").json()
    assert len(body) == 10 and isinstance(body, list)


def test_produits_inactifs_exclus(api):
    make_product("Banane", is_active=False)
    make_product("Banane plantain")
    assert [p["name"] for p in search(api, "banane").json()] == ["Banane plantain"]


def test_aucun_resultat_est_une_liste_vide(api):
    make_product("Banane")
    resp = search(api, "zzz")
    assert resp.status_code == 200 and resp.json() == []


def test_forme_de_la_reponse_et_aucun_numero(api):
    sector = make_sector()
    sub = make_subcategory(sector)
    make_product("Mangue", category=sub)
    make_product("Sel")
    mangue = search(api, "mangue").json()[0]
    assert set(mangue) == {"id", "name", "sector", "subcategory"}
    assert (mangue["sector"], mangue["subcategory"]) == ("alimentation", "fruits")
    sel = search(api, "sel").json()[0]
    assert sel["sector"] is None and sel["subcategory"] is None


@pytest.mark.parametrize("q", ["", "   ", "!?", None])
def test_q_vide_ou_absent_400(api, q):
    resp = api.get("/api/catalog/products/") if q is None else search(api, q)
    assert resp.status_code == 400
    assert resp.json()["code"] == "invalid" and "q" in resp.json()["fields"]


def test_q_trop_long_400_et_100_caracteres_accepte(api):
    assert search(api, "a" * 101).status_code == 400
    assert search(api, "a" * 100).status_code == 200


def test_recherche_sans_jeton(api):
    make_product("Banane")
    api.credentials(HTTP_AUTHORIZATION="Bearer nimporte.quoi")
    assert search(api, "ban").status_code == 200


def test_q_avec_caracteres_speciaux_de_like_traite_comme_du_texte(api):
    make_product("Banane")
    assert search(api, "b_n").json() == []  # « _ » n'est pas un joker
    assert search(api, "100%").json() == []  # « % » est de la ponctuation, pas un joker


# --- Admin ----------------------------------------------------------------------------


@pytest.fixture
def admin_browser():
    from django.test import Client

    from tests.factories.user_factory import UserFactory

    user = UserFactory(is_admin=True, is_staff=True, is_superuser=True)
    client = Client()
    client.force_login(user)
    return client


@pytest.mark.parametrize(
    "model", ["sector", "subcategory", "servicecategory", "structuretype", "catalogproduct",
              "synonym"]
)
def test_admin_liste_de_chaque_modele(admin_browser, seeded, model):
    assert admin_browser.get(f"/django-admin/catalog/{model}/").status_code == 200
    assert admin_browser.get(f"/django-admin/catalog/{model}/add/").status_code == 200


def test_admin_secteur_avec_sous_categories_en_ligne_et_modification(admin_browser, seeded):
    sector = Sector.objects.get(code="alimentation")
    resp = admin_browser.get(f"/django-admin/catalog/sector/{sector.id}/change/")
    assert resp.status_code == 200 and "Fruits" in resp.content.decode()
    subs = list(sector.subcategories.order_by("order"))
    data = {
        "name": "Nourriture", "icon": "🍌", "order": 1, "is_active": "on",
        "subcategories-TOTAL_FORMS": len(subs), "subcategories-INITIAL_FORMS": len(subs),
        "subcategories-MIN_NUM_FORMS": 0, "subcategories-MAX_NUM_FORMS": 1000,
    }
    for i, sub in enumerate(subs):
        data.update({
            f"subcategories-{i}-id": sub.id, f"subcategories-{i}-sector": sector.id,
            f"subcategories-{i}-code": sub.code, f"subcategories-{i}-name": sub.name,
            f"subcategories-{i}-icon": "", f"subcategories-{i}-order": sub.order,
            f"subcategories-{i}-is_active": "on",
        })
    data["subcategories-0-name"] = "Fruits frais"
    resp = admin_browser.post(f"/django-admin/catalog/sector/{sector.id}/change/", data)
    assert resp.status_code == 302
    sector.refresh_from_db()
    assert sector.name == "Nourriture"
    assert sector.subcategories.get(code="fruits").name == "Fruits frais"


def test_admin_code_invalide_refuse_et_code_fige_apres_creation(admin_browser):
    data = {"code": "Code Invalide", "name": "X", "icon": "", "order": 1, "is_active": "on",
            "subcategories-TOTAL_FORMS": 0, "subcategories-INITIAL_FORMS": 0,
            "subcategories-MIN_NUM_FORMS": 0, "subcategories-MAX_NUM_FORMS": 1000}
    resp = admin_browser.post("/django-admin/catalog/sector/add/", data)
    assert resp.status_code == 200 and not Sector.objects.exists()
    data["code"] = "nouveau_secteur"
    assert admin_browser.post("/django-admin/catalog/sector/add/", data).status_code == 302
    sector = Sector.objects.get(code="nouveau_secteur")
    resp = admin_browser.get(f"/django-admin/catalog/sector/{sector.id}/change/")
    assert 'name="code"' not in resp.content.decode()


def test_admin_produit_applique_la_validation_du_modele(admin_browser):
    make_product("Banane")
    other = make_product("Mangue")
    data = {"name": "BANANE", "category": "", "is_active": "on",
            "synonyms-TOTAL_FORMS": 0, "synonyms-INITIAL_FORMS": 0,
            "synonyms-MIN_NUM_FORMS": 0, "synonyms-MAX_NUM_FORMS": 1000}
    resp = admin_browser.post(f"/django-admin/catalog/catalogproduct/{other.id}/change/", data)
    assert resp.status_code == 200
    other.refresh_from_db()
    assert other.name == "Mangue"
    data["name"] = "Mangue verte"
    resp = admin_browser.post(f"/django-admin/catalog/catalogproduct/{other.id}/change/", data)
    assert resp.status_code == 302
    other.refresh_from_db()
    assert other.normalized_name == "mangue verte"


def test_admin_interdit_sans_connexion(client):
    assert client.get("/django-admin/catalog/sector/").status_code == 302
