"""seed_referentials (T021) : contenu exact de la spec, idempotence, CSV facultatifs."""
import json
from io import StringIO
from pathlib import Path

import pytest
from django.core.management import call_command
from django.core.management.base import CommandError

from apps.catalog.models import (
    CatalogProduct,
    Sector,
    ServiceCategory,
    StructureType,
    Subcategory,
    Synonym,
)

pytestmark = pytest.mark.django_db

DATA = Path(__file__).resolve().parents[1] / "data"


def seed(**options):
    out = StringIO()
    call_command("seed_referentials", stdout=out, **options)
    return out.getvalue()


def names(queryset):
    return list(queryset.order_by("order").values_list("name", flat=True))


def test_dix_secteurs_avec_icone_dans_l_ordre_de_la_spec():
    seed()
    sectors = list(Sector.objects.order_by("order").values_list("name", "icon"))
    assert sectors == [
        ("Alimentation", "🍌"), ("Boutique / Supérette", "🏪"), ("Pharmacie & Santé", "💊"),
        ("Mode & Beauté", "👗"), ("Électronique & Informatique", "💻"), ("Immobilier", "🏠"),
        ("Transport & Livraison", "🛵"), ("Agriculture & Élevage", "🌾"),
        ("Artisanat & Services à domicile", "🔧"), ("Autre", "✨"),
    ]


def test_sous_categories_des_quatre_secteurs_detailles():
    seed()
    sub = lambda code: names(Subcategory.objects.filter(sector__code=code))  # noqa: E731
    assert sub("alimentation") == [
        "Fruits", "Légumes", "Tubercules", "Céréales & Légumineuses",
        "Viande/Volaille & Poisson", "Produits laitiers & Œufs", "Huiles & Graisses",
        "Épices & Condiments", "Boissons", "Boulangerie & Pâtisserie", "Produits surgelés",
        "Autre",
    ]
    assert sub("boutique_superette") == [
        "Biscuits & Confiseries", "Eau & Boissons", "Pâtes/Riz & Céréales transformées",
        "Conserves", "Produits laitiers emballés", "Hygiène & Entretien",
        "Produits pour bébés", "Papeterie", "Autre",
    ]
    assert sub("transport_livraison") == [
        "Moto-taxi", "Taxi", "Livraison de colis", "Transport de marchandises",
        "Location de véhicule", "Déménagement", "Autre",
    ]
    assert sub("artisanat_services_domicile") == [
        "Menuiserie", "Plomberie", "Électricité", "Couture", "Maçonnerie", "Mécanique",
        "Informatique & Réparation", "Coiffure & Beauté", "Autre",
    ]


def test_les_six_autres_secteurs_n_ont_que_autre():
    seed()
    for code in ("pharmacie_sante", "mode_beaute", "electronique_informatique", "immobilier",
                 "agriculture_elevage", "autre"):
        assert names(Subcategory.objects.filter(sector__code=code)) == ["Autre"], code


def test_sept_categories_de_service_et_cinq_types_de_structure():
    seed()
    assert names(ServiceCategory.objects) == [
        "Enseignement à domicile", "Technique & Réparation", "Services médicaux indépendants",
        "Beauté & Bien-être à domicile", "Juridique & Comptabilité", "Événementiel", "Autre",
    ]
    assert list(StructureType.objects.order_by("order").values_list("name", "icon")) == [
        ("Supermarché", "🛒"), ("Restaurant", "🍲"), ("Hôtel", "🏨"),
        ("Centre de santé", "🏥"), ("Autre", "✨"),
    ]


def test_catalogue_vide_tant_que_jeff_n_a_rien_fourni():
    seed()
    assert CatalogProduct.objects.count() == 0 and Synonym.objects.count() == 0


def test_idempotent():
    first = seed()
    counts = (Sector.objects.count(), Subcategory.objects.count(), ServiceCategory.objects.count(),
              StructureType.objects.count())
    assert counts == (10, 43, 7, 5)
    assert "Secteurs : 10 créés, 0 déjà présents" in first
    second = seed()
    assert "Secteurs : 0 créés, 10 déjà présents" in second
    assert "Sous-catégories : 0 créés, 43 déjà présents" in second
    assert counts == (Sector.objects.count(), Subcategory.objects.count(),
                      ServiceCategory.objects.count(), StructureType.objects.count())


def test_ne_remplace_pas_les_modifications_de_l_admin():
    seed()
    sector = Sector.objects.get(code="alimentation")
    sector.name, sector.order, sector.is_active = "Nourriture", 99, False
    sector.save()
    Subcategory.objects.filter(code="fruits").update(name="Fruits frais", is_active=False)
    seed()
    sector.refresh_from_db()
    assert (sector.name, sector.order, sector.is_active) == ("Nourriture", 99, False)
    fruits = Subcategory.objects.get(sector=sector, code="fruits")
    assert fruits.name == "Fruits frais" and fruits.is_active is False
    assert Sector.objects.count() == 10 and Subcategory.objects.count() == 43


def test_une_ligne_supprimee_dans_l_admin_est_recreee_sans_toucher_aux_autres():
    seed()
    ServiceCategory.objects.get(code="evenementiel").delete()
    out = seed()
    assert "Catégories de service : 1 créés, 6 déjà présents" in out


def test_le_fichier_de_depart_est_coherent():
    data = json.loads((DATA / "categories.json").read_text(encoding="utf-8"))
    assert len(data["sectors"]) == 10
    assert len(data["service_categories"]) == 7 and len(data["structure_types"]) == 5
    assert (DATA / "products.csv").read_text(encoding="utf-8").strip() == (
        "name,sector_code,subcategory_code"
    )
    assert (DATA / "synonyms.csv").read_text(encoding="utf-8").strip() == "term,product_name"


def write_data_dir(tmp_path, products="", synonyms=""):
    (tmp_path / "categories.json").write_text(
        (DATA / "categories.json").read_text("utf-8"), encoding="utf-8"
    )
    (tmp_path / "products.csv").write_text(
        "name,sector_code,subcategory_code\n" + products, encoding="utf-8"
    )
    (tmp_path / "synonyms.csv").write_text("term,product_name\n" + synonyms, encoding="utf-8")
    return str(tmp_path)


def test_csv_produits_et_synonymes_charges_sans_doublon(tmp_path):
    folder = write_data_dir(
        tmp_path,
        "Produit d'essai,alimentation,fruits\nAutre essai,,\n",
        "terme d'essai,Produit d'essai\n",
    )
    out = seed(data_dir=folder)
    assert "Produits : 2 créés, 0 déjà présents" in out and "Synonymes : 1 créés" in out
    product = CatalogProduct.objects.get(name="Produit d'essai")
    assert product.category.code == "fruits" and product.category.sector.code == "alimentation"
    assert CatalogProduct.objects.get(name="Autre essai").category is None
    out = seed(data_dir=folder)
    assert "Produits : 0 créés, 2 déjà présents" in out and "Synonymes : 0 créés, 1 déjà" in out
    assert CatalogProduct.objects.count() == 2 and Synonym.objects.count() == 1


def test_csv_sous_categorie_inconnue_refusee_et_tout_annule(tmp_path):
    folder = write_data_dir(tmp_path, "Bon,alimentation,fruits\nMauvais,alimentation,inconnue\n")
    with pytest.raises(CommandError, match="products.csv ligne 3"):
        seed(data_dir=folder)
    assert CatalogProduct.objects.count() == 0 and Sector.objects.count() == 0


def test_csv_synonyme_d_un_produit_inconnu_refuse(tmp_path):
    folder = write_data_dir(tmp_path, "", "mot,Produit absent\n")
    with pytest.raises(CommandError, match="synonyms.csv ligne 2"):
        seed(data_dir=folder)


def test_csv_colonnes_manquantes_refusees(tmp_path):
    folder = write_data_dir(tmp_path)
    (tmp_path / "products.csv").write_text("name\nX\n", encoding="utf-8")
    with pytest.raises(CommandError, match="colonnes manquantes"):
        seed(data_dir=folder)


def test_dossier_sans_categories_json_refuse(tmp_path):
    with pytest.raises(CommandError, match="introuvable"):
        seed(data_dir=str(tmp_path))
