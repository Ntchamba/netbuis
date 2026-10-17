"""Fabriques du catalogue : secteur, sous-catégorie, produit, synonyme."""
from apps.catalog.models import CatalogProduct, Sector, Subcategory, Synonym


def make_sector(code="alimentation", name="Alimentation", icon="🍌", **extra):
    return Sector.objects.create(code=code, name=name, icon=icon, **extra)


def make_subcategory(sector, code="fruits", name="Fruits", **extra):
    return Subcategory.objects.create(sector=sector, code=code, name=name, **extra)


def make_product(name, category=None, synonyms=(), **extra):
    product = CatalogProduct.objects.create(name=name, category=category, **extra)
    for term in synonyms:
        Synonym.objects.create(product=product, term=term)
    return product
