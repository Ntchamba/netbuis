"""Modèles du catalogue (T021) : normalisation, unicité, codes stables, index trigramme."""
import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError, connection, transaction

from apps.catalog.models import CatalogProduct, Sector, Subcategory, Synonym
from apps.catalog.services.normalize import normalize_query
from tests.factories.catalog_factory import make_product, make_sector, make_subcategory

pytestmark = pytest.mark.django_db


def test_nom_produit_normalise_a_l_enregistrement():
    product = make_product("Pâte d'Arachide  ÉPICÉE")
    assert product.normalized_name == "pate d arachide epicee"
    product.name = "Plantain Mûr"
    product.save()
    product.refresh_from_db()
    assert product.normalized_name == "plantain mur"


def test_produit_sans_nom_refuse():
    with pytest.raises(ValidationError):
        CatalogProduct(name="  !! ").save()


def test_doublon_de_produit_refuse_meme_avec_accents_ou_casse():
    make_product("Plantain")
    with pytest.raises(ValidationError):
        make_product("PLANTAIN")
    with pytest.raises(IntegrityError), transaction.atomic():
        CatalogProduct.objects.bulk_create(
            [CatalogProduct(name="x", normalized_name="plantain")]
        )


def test_synonyme_normalise_et_unique_par_produit():
    product = make_product("Riz", synonyms=["Rice"])
    synonym = product.synonyms.get()
    assert synonym.normalized_term == "rice"
    with pytest.raises(ValidationError):
        Synonym(product=product, term="RICE").save()
    other = make_product("Riz parfumé")
    Synonym(product=other, term="rice").save()  # le même mot peut viser un autre produit
    assert Synonym.objects.filter(normalized_term="rice").count() == 2


def test_synonyme_vide_refuse():
    product = make_product("Riz")
    with pytest.raises(ValidationError):
        Synonym(product=product, term="?").save()


def test_categorie_du_produit_facultative_et_conservee_a_la_suppression():
    sector = make_sector()
    sub = make_subcategory(sector)
    product = make_product("Mangue", category=sub)
    assert product.category.sector == sector
    sub.delete()
    product.refresh_from_db()
    assert product.category is None


def test_code_stable_unique_pour_les_secteurs_et_par_secteur_pour_les_sous_categories():
    sector = make_sector()
    with pytest.raises(IntegrityError), transaction.atomic():
        make_sector(code="alimentation", name="Autre nom")
    other = make_sector(code="boutique_superette", name="Boutique / Supérette")
    make_subcategory(sector, code="autre", name="Autre")
    make_subcategory(other, code="autre", name="Autre")  # même code dans un autre secteur
    with pytest.raises(IntegrityError), transaction.atomic():
        make_subcategory(sector, code="autre", name="Autre bis")


@pytest.mark.parametrize("code", ["Alimentation", "boutique-superette", "épices", "a b", "_x", ""])
def test_code_invalide_refuse_par_la_validation(code):
    with pytest.raises(ValidationError) as exc:
        Sector(code=code, name="X").full_clean()
    assert "code" in exc.value.message_dict


def test_code_valide_accepte():
    Sector(code="boutique_superette", name="X").full_clean()


def test_cascade_secteur_vers_sous_categories():
    sector = make_sector()
    make_subcategory(sector)
    sector.delete()
    assert Subcategory.objects.count() == 0 and Sector.objects.count() == 0


def test_normalize_query():
    assert normalize_query("  ÉPICES! ") == "epices"
    assert normalize_query(None) == "" and normalize_query("?!") == ""


def test_index_trigramme_presents_en_base():
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT indexname, indexdef FROM pg_indexes "
            "WHERE indexname IN ('catalog_product_name_trgm', 'catalog_synonym_term_trgm')"
        )
        rows = dict(cursor.fetchall())
    assert set(rows) == {"catalog_product_name_trgm", "catalog_synonym_term_trgm"}
    assert all("gin_trgm_ops" in definition for definition in rows.values())


def test_synonyme_actif_par_defaut_et_recherche_ignore_les_inactifs():
    from apps.search.text.synonyms_expand import matching_products

    product = make_product("Ndolé", synonyms=["tchop"])
    synonym = Synonym.objects.get(product=product, term="tchop")
    assert synonym.is_active is True
    assert product.pk in matching_products("tchop")
    synonym.is_active = False
    synonym.save()
    assert product.pk not in matching_products("tchop")
    synonym.is_active = True
    synonym.save()
    assert product.pk in matching_products("tchop")
