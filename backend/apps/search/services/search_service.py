"""Moteur de recherche (T040) : orchestration. Le téléphone n'est jamais renvoyé.

`search()` renvoie les résultats classés (identifiants + score) ; `SearchOutcome.profiles()`
charge ensuite une page de profils SANS les champs sensibles (numéro ancré, CNI, diplôme).

Un compte business correspond si l'un de ces éléments ressemble au terme (poids entre
parenthèses : un secteur large compte moins qu'une offre précise) :
- une de ses offres actives, par le nom (1,0) ou par le produit du catalogue relié (score du
  produit) ;
- une de ses sous-catégories (0,9) ;
- sa catégorie de service, ou son texte libre (0,9) ;
- son secteur, ou son texte libre (0,7).
Seuls les profils de `BusinessProfile.objects.visible()` peuvent sortir.
"""
from dataclasses import dataclass

from apps.business.models import BusinessProfile, Offer
from apps.business.services.subscription import subscribed_profiles
from apps.search.models import SearchMode
from apps.search.services import filters, ranking
from apps.search.services.logging import log_search
from apps.search.text.normalize import normalize_search_term
from apps.search.text.synonyms_expand import expand
from apps.search.text.trigram_query import (
    SIMILARITY_THRESHOLD,
    active_text,
    best_score,
    plain_text,
)

WEIGHT_OFFER = 1.0
WEIGHT_SUBCATEGORY = 0.9
WEIGHT_SERVICE = 0.9
WEIGHT_SECTOR = 0.7

SENSITIVE_FIELDS = ("phone_anchor", "cni_photo", "diplome_photo")


def _weighted(terms, weight):
    return [(text, w * weight) for text, w in terms]


@dataclass
class SearchOutcome:
    term: str
    hits: list  # list[ranking.Hit], déjà classés

    @property
    def total(self) -> int:
        return len(self.hits)

    def profiles(self, offset: int = 0, limit: int | None = None) -> list:
        """Les profils de la tranche demandée, dans l'ordre du classement. Les champs sensibles
        (numéro ancré, CNI, diplôme) ne sont pas chargés."""
        window = self.hits[offset:None if limit is None else offset + limit]
        ids = [hit.profile_id for hit in window]
        loaded = (
            BusinessProfile.objects.visible().filter(pk__in=ids)
            .select_related("zone", "zone__parent", "secteur", "categorie_service")
            .defer(*SENSITIVE_FIELDS)
            .in_bulk()
        )
        return [loaded[pk] for pk in ids if pk in loaded]


def _offer_scores(base_ids, expansion) -> dict:
    scores: dict = {}
    by_name = (
        Offer.objects.filter(is_active=True, profile__in=base_ids)
        .annotate(score=best_score(_weighted(expansion.terms, WEIGHT_OFFER), plain_text("name")))
        .filter(score__gte=SIMILARITY_THRESHOLD)
        .values_list("profile_id", "score")
    )
    by_product = (
        Offer.objects.filter(
            is_active=True, profile__in=base_ids, catalog_product__in=list(expansion.products)
        ).values_list("profile_id", "catalog_product_id")
    )
    for profile_id, score in by_name:
        scores[profile_id] = max(score, scores.get(profile_id, 0.0))
    for profile_id, product_id in by_product:
        scores[profile_id] = max(expansion.products[product_id], scores.get(profile_id, 0.0))
    return scores


def _subcategory_scores(base_ids, terms) -> dict:
    through = BusinessProfile.sous_categories.through
    rows = (
        through.objects.filter(businessprofile__in=base_ids, subcategory__is_active=True)
        .annotate(score=best_score(_weighted(terms, WEIGHT_SUBCATEGORY),
                                   plain_text("subcategory__name")))
        .filter(score__gte=SIMILARITY_THRESHOLD)
        .values_list("businessprofile_id", "score")
    )
    scores: dict = {}
    for profile_id, score in rows:
        scores[profile_id] = max(score, scores.get(profile_id, 0.0))
    return scores


def _profile_field_scores(base, terms) -> dict:
    """Secteur, catégorie de service et leurs textes libres, en une requête."""
    columns = {
        "s_sector": (active_text("secteur__name", "secteur__is_active"), WEIGHT_SECTOR),
        "s_sector_free": (plain_text("secteur_libre"), WEIGHT_SECTOR),
        "s_service": (
            active_text("categorie_service__name", "categorie_service__is_active"),
            WEIGHT_SERVICE,
        ),
        "s_service_free": (plain_text("categorie_service_libre"), WEIGHT_SERVICE),
    }
    annotations = {
        name: best_score(_weighted(terms, weight), expression)
        for name, (expression, weight) in columns.items()
    }
    rows = base.annotate(**annotations).values_list("pk", *columns)
    scores: dict = {}
    for pk, *values in rows:
        best = max((v for v in values if v is not None), default=0.0)
        if best >= SIMILARITY_THRESHOLD:
            scores[pk] = best
    return scores


def relevance_scores(base, term: str) -> dict:
    """`{id du profil: score}` des profils de `base` qui correspondent au terme."""
    expansion = expand(term)
    base_ids = base.values("pk")
    merged: dict = {}
    for source in (
        _offer_scores(base_ids, expansion),
        _subcategory_scores(base_ids, expansion.terms),
        _profile_field_scores(base, expansion.terms),
    ):
        for profile_id, score in source.items():
            merged[profile_id] = max(score, merged.get(profile_id, 0.0))
    return merged


def search(q: str | None, *, zone=None, near=None, sector=None, user=None,
           mode: str = SearchMode.TEXT, log: bool = True) -> SearchOutcome:
    """Recherche classée.

    - `zone` : filtre — seuls les comptes de cette zone (et de celles qu'elle contient).
    - `near` : zone de référence pour la proximité (par défaut `zone`) ; ne filtre rien.
    - `sector` : filtre par secteur (instance, code stable ou identifiant).
    - `q` vide : tous les comptes visibles du filtre (c'est la liste de l'Accueil).
    """
    term = normalize_search_term(q)
    parents = filters.zone_parents() if (zone is not None or near is not None) else {}
    zone_ids = filters.zone_subtree_ids(zone, parents) if zone is not None else None
    base = filters.apply_filters(
        BusinessProfile.objects.visible(), zone_ids=zone_ids,
        sector=filters.resolve_sector(sector),
    )

    if term:
        scores = relevance_scores(base, term)
        candidates = base.filter(pk__in=list(scores))
    else:
        scores = {}
        candidates = base
    placed = dict(candidates.values_list("pk", "zone_id"))
    subscribed = set(
        subscribed_profiles(candidates).values_list("pk", flat=True)
    )
    reference = near if near is not None else zone
    reference_id = reference.pk if reference is not None else None
    hits = ranking.rank(
        ranking.Hit(
            profile_id=pk, score=scores.get(pk, 0.0), subscribed=pk in subscribed,
            proximity=ranking.zone_distance(zone_id, reference_id, parents),
        )
        for pk, zone_id in placed.items()
    )
    if log:
        log_search(term, zone=zone, results_count=len(hits), user=user, mode=mode)
    return SearchOutcome(term=term, hits=hits)
