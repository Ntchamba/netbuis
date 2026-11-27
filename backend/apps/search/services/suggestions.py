"""Suggestions pendant la frappe (T041) : produits du catalogue, puis termes souvent cherchés."""
from django.db.models import BooleanField, Case, Count, Value, When

from apps.catalog.models import CatalogProduct
from apps.catalog.services.normalize import MAX_QUERY_LENGTH
from apps.search.models import SearchLog
from apps.search.text.normalize import normalize_search_term

MAX_SUGGESTIONS = 8
MIN_CHARS = 2


def suggest(raw: str | None) -> list:
    """Au plus 8 `{"text", "type"}` : produits actifs du catalogue (commençant par le terme
    d'abord), puis termes fréquents du journal de recherche qui ont donné des résultats.
    Moins de 2 caractères : rien."""
    term = normalize_search_term((raw or "")[:MAX_QUERY_LENGTH])
    if len(term) < MIN_CHARS:
        return []
    products = (
        CatalogProduct.objects.filter(is_active=True, normalized_name__contains=term)
        .annotate(rank=Case(
            When(normalized_name__startswith=term, then=Value(0)), default=Value(1),
            output_field=BooleanField(),
        ))
        .order_by("rank", "normalized_name", "id")
        .values_list("name", "normalized_name")[:MAX_SUGGESTIONS]
    )
    products = list(products)
    suggestions = [{"text": name, "type": "produit"} for name, _ in products]
    seen = {normalized for _, normalized in products}
    room = MAX_SUGGESTIONS - len(suggestions)
    if room > 0:
        frequent = (
            SearchLog.objects.filter(term__contains=term, results_count__gt=0)
            .values("term").annotate(total=Count("id"))
            .order_by("-total", "term")[: room + len(seen)]
        )
        for row in frequent:
            if row["term"] in seen:
                continue
            suggestions.append({"text": row["term"], "type": "recherche"})
            seen.add(row["term"])
            if len(suggestions) == MAX_SUGGESTIONS:
                break
    return suggestions
