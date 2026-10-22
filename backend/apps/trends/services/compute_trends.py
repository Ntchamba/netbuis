"""Calcul des tendances par ville (T104), à partir de `SearchLog` et `CallLog`.

- Produits : les termes cherchés qui sont EXACTEMENT le nom (ou un synonyme actif) d'un produit
  actif du catalogue. Le texte libre n'est jamais classé (donc aucun numéro ni donnée
  personnelle ne peut sortir).
- Commerces : contacts (appel + WhatsApp) des commerces visibles (`BusinessProfile.visible()`).
- Ville : la zone de la recherche ou du commerce est ramenée à la ville/village qui la contient
  (elle-même si c'en est une) ; une zone au-dessus d'une ville est ignorée.
- Seuil et durée : PlatformSetting (`trends_*`). Un instantané par (ville, jour) : relancer le
  calcul le même jour remplace l'instantané.
"""
from collections import defaultdict
from datetime import timedelta

from django.db import transaction
from django.db.models import Count
from django.utils import timezone

from apps.business.models import BusinessProfile
from apps.calls.models import CallLog
from apps.catalog.models import CatalogProduct, Synonym
from apps.core.models.platform_setting import SettingKey
from apps.core.services.settings_service import get_setting
from apps.geo.models import Zone, ZoneLevel
from apps.search.models import SearchLog
from apps.trends.models import TrendEntry, TrendKind, TrendSnapshot
from apps.trends.services.scoring import Candidate, rank


class CityResolver:
    """Ramène n'importe quelle zone à sa ville/village (une seule lecture de la hiérarchie)."""

    def __init__(self):
        self._nodes = {pk: (parent, level) for pk, parent, level in
                       Zone.objects.values_list("pk", "parent_id", "level")}

    def city_id(self, zone_id) -> int | None:
        seen = set()
        while zone_id is not None and zone_id not in seen:
            seen.add(zone_id)
            node = self._nodes.get(zone_id)
            if node is None:
                return None
            parent, level = node
            if level == ZoneLevel.VILLE_VILLAGE:
                return zone_id
            zone_id = parent
        return None


def _term_to_product() -> dict:
    """`{terme normalisé: (id du produit, nom)}` : noms et synonymes actifs, produits actifs."""
    mapping = {}
    for synonym in (Synonym.objects.filter(is_active=True, product__is_active=True)
                    .select_related("product")):
        mapping[synonym.normalized_term] = (synonym.product_id, synonym.product.name)
    for pk, normalized, name in CatalogProduct.objects.filter(is_active=True).values_list(
            "pk", "normalized_name", "name"):
        mapping[normalized] = (pk, name)  # le nom officiel l'emporte sur un synonyme
    return mapping


def _product_candidates(since, resolver) -> dict:
    """`{ville: [Candidate]}` : recherches et comptes distincts par produit et par ville."""
    terms = _term_to_product()
    rows = (
        SearchLog.objects.filter(created_at__gte=since, zone__isnull=False, term__in=terms)
        .values("zone_id", "term", "account_hash").annotate(n=Count("id"))
    )
    hits: dict = defaultdict(int)
    accounts: dict = defaultdict(set)
    for row in rows:
        city = resolver.city_id(row["zone_id"])
        if city is None:
            continue
        product_id, _ = terms[row["term"]]
        hits[city, product_id] += row["n"]
        if row["account_hash"]:
            accounts[city, product_id].add(row["account_hash"])
    names = {pk: name for pk, name in terms.values()}
    out: dict = defaultdict(list)
    for (city, product_id), count in hits.items():
        out[city].append(Candidate(
            key=product_id, hits=count, accounts=len(accounts[city, product_id]),
            label=names[product_id],
        ))
    return out


def _business_candidates(since, resolver) -> dict:
    """`{ville: [Candidate]}` : contacts (appel + WhatsApp) par commerce visible."""
    visible = BusinessProfile.objects.visible()
    rows = (
        CallLog.objects.filter(created_at__gte=since, profile__in=visible)
        .values("profile_id", "profile__zone_id", "profile__name")
        .annotate(n=Count("id"), callers=Count("caller_id", distinct=True))
    )
    out: dict = defaultdict(list)
    for row in rows:
        city = resolver.city_id(row["profile__zone_id"])
        if city is None:
            continue
        out[city].append(Candidate(
            key=row["profile_id"], hits=row["n"], accounts=row["callers"],
            label=row["profile__name"],
        ))
    return out


def compute_trends(now=None) -> dict:
    """Calcule et enregistre les instantanés ; retourne `{"cities": n, "entries": n}`."""
    now = now or timezone.now()
    window = get_setting(SettingKey.TRENDS_WINDOW_DAYS)
    min_hits = get_setting(SettingKey.TRENDS_MIN_SEARCHES)
    min_accounts = get_setting(SettingKey.TRENDS_MIN_ACCOUNTS)
    since = now - timedelta(days=window)
    period_end = timezone.localdate(now)
    resolver = CityResolver()
    products = _product_candidates(since, resolver)
    businesses = _business_candidates(since, resolver)
    # Les villes qui ont déjà un instantané reçoivent aussi le nouveau (éventuellement vide),
    # sinon l'ancien classement resterait affiché.
    cities = set(products) | set(businesses) | set(
        TrendSnapshot.objects.values_list("zone_id", flat=True))
    entries = 0
    with transaction.atomic():
        for city in sorted(cities):
            TrendSnapshot.objects.filter(zone_id=city, period_end=period_end).delete()
            snapshot = TrendSnapshot.objects.create(
                zone_id=city, period_end=period_end, window_days=window)
            rows = []
            for kind, pool in ((TrendKind.PRODUCT, products), (TrendKind.BUSINESS, businesses)):
                ranked = rank(pool.get(city, []), min_hits=min_hits, min_accounts=min_accounts)
                for position, cand in enumerate(ranked, start=1):
                    target = ({"product_id": cand.key} if kind == TrendKind.PRODUCT
                              else {"profile_id": cand.key})
                    rows.append(TrendEntry(
                        snapshot=snapshot, kind=kind, rank=position, hits=cand.hits,
                        accounts=cand.accounts, **target))
            TrendEntry.objects.bulk_create(rows)
            entries += len(rows)
    return {"cities": len(cities), "entries": entries}
