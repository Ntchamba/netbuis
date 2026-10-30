"""Synonymes : élargit le terme cherché avec les produits du catalogue qui lui ressemblent
(par leur nom ou par un synonyme), tolérance aux fautes comprise.

« tchop » → produit « Ndolé » si c'est un de ses synonymes : la recherche cherche alors aussi
« ndole » et les offres reliées à ce produit.
"""
from dataclasses import dataclass, field

from apps.catalog.models import CatalogProduct, Synonym
from apps.search.text.trigram_query import SIMILARITY_THRESHOLD, best_score, plain_text

MAX_PRODUCTS = 5


@dataclass
class Expansion:
    """Termes `(texte, poids)` à chercher et produits du catalogue reconnus `{id: score}`."""

    terms: list = field(default_factory=list)
    products: dict = field(default_factory=dict)


def matching_products(term: str) -> dict:
    """`{id du produit: score}` pour les produits actifs dont le nom ou un synonyme ressemble."""
    scores: dict = {}
    by_name = (
        CatalogProduct.objects.filter(is_active=True)
        .annotate(score=best_score([(term, 1.0)], plain_text("normalized_name")))
        .filter(score__gte=SIMILARITY_THRESHOLD)
        .values_list("pk", "score")
    )
    by_synonym = (
        Synonym.objects.filter(product__is_active=True, is_active=True)
        .annotate(score=best_score([(term, 1.0)], plain_text("normalized_term")))
        .filter(score__gte=SIMILARITY_THRESHOLD)
        .values_list("product_id", "score")
    )
    for product_id, score in [*by_name, *by_synonym]:
        scores[product_id] = max(score, scores.get(product_id, 0.0))
    best = sorted(scores.items(), key=lambda item: (-item[1], item[0]))[:MAX_PRODUCTS]
    return dict(best)


def expand(term: str) -> Expansion:
    """Le terme lui-même (poids 1) + le nom des produits reconnus (poids = leur ressemblance)."""
    products = matching_products(term)
    terms = [(term, 1.0)]
    names = dict(
        CatalogProduct.objects.filter(pk__in=products).values_list("pk", "normalized_name")
    )
    for product_id, score in products.items():
        name = names.get(product_id)
        if name and name != term:
            terms.append((name, min(score, 1.0)))
    return Expansion(terms=terms, products=products)
