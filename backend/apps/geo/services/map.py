"""Carte par zones (T060) : villes actives, quartiers, commerces d'un quartier.

Règle (D-13) : une ville / un village n'apparaît que s'il compte au moins un commerce
`actif` (visible() : propriétaire ni bloqué ni supprimé), directement ou par un quartier.
Un profil rattaché à autre chose qu'une ville ou un quartier n'est JAMAIS compté.
Les compteurs viennent d'agrégats SQL (nombre de requêtes borné, pas de N+1).
"""
from django.db.models import Case, Count, F, Q, When

from apps.business.models import BusinessProfile, Offer
from apps.core.utils.text_normalize import normalize_text
from apps.geo.models import Zone, ZoneLevel

_CITY_ID = Case(
    When(zone__level=ZoneLevel.QUARTIER, then=F("zone__parent_id")),
    When(zone__level=ZoneLevel.VILLE_VILLAGE, then=F("zone_id")),
    default=None,
)
# Lieu valable pour la carte : ville active, ou quartier actif d'une ville active.
_MAPPED = (
    Q(zone__level=ZoneLevel.VILLE_VILLAGE, zone__is_active=True)
    | Q(zone__level=ZoneLevel.QUARTIER, zone__is_active=True, zone__parent__is_active=True)
)


def mapped_profiles():
    """Commerces visibles rattachés à une ville ou un quartier actifs."""
    return BusinessProfile.objects.visible().filter(_MAPPED)


def business_counts_by_city() -> dict:
    rows = (
        mapped_profiles().annotate(city_id=_CITY_ID).values("city_id")
        .annotate(total=Count("pk")).values_list("city_id", "total")
    )
    return dict(rows)


def active_cities(query: str = ""):
    """`(villes, nombre de commerces par ville)` ; les ancêtres des villes sont chargés."""
    counts = business_counts_by_city()
    cities = Zone.objects.filter(
        level=ZoneLevel.VILLE_VILLAGE, is_active=True, pk__in=list(counts)
    ).select_related("parent__parent__parent__parent")
    needle = normalize_text(query)
    if needle:
        cities = cities.filter(normalized_name__contains=needle)
    return list(cities), counts


def ancestor(zone, level):
    node = zone.parent
    while node is not None and node.level != level:
        node = node.parent
    return node


def explorable_hierarchy() -> list:
    """Régions actives (avec leurs départements actifs) marquées `explorable` si elles
    contiennent une ville active. Liste de dicts prête à sérialiser."""
    cities, _ = active_cities()
    regions_ok = {ancestor(c, ZoneLevel.REGION).pk for c in cities if ancestor(c, ZoneLevel.REGION)}
    deps_ok = {
        ancestor(c, ZoneLevel.DEPARTEMENT).pk for c in cities
        if ancestor(c, ZoneLevel.DEPARTEMENT)
    }
    departements: dict = {}
    for dep in Zone.objects.filter(level=ZoneLevel.DEPARTEMENT, is_active=True):
        departements.setdefault(dep.parent_id, []).append(
            {"id": dep.pk, "name": dep.name, "explorable": dep.pk in deps_ok}
        )
    return [
        {
            "id": region.pk, "name": region.name, "explorable": region.pk in regions_ok,
            "departements": departements.get(region.pk, []),
        }
        for region in Zone.objects.filter(level=ZoneLevel.REGION, is_active=True)
    ]


def area_stats(city):
    """Quartiers actifs de `city` comptant au moins un commerce : `[(quartier, commerces,
    produits)]`, et le nombre de commerces rattachés directement à la ville."""
    profile_rows = dict(
        mapped_profiles().filter(Q(zone__parent=city) | Q(zone=city)).values("zone_id")
        .annotate(total=Count("pk")).values_list("zone_id", "total")
    )
    offer_rows = dict(
        Offer.objects.filter(
            is_active=True, profile__in=mapped_profiles().filter(zone__parent=city).values("pk")
        ).values("profile__zone_id").annotate(total=Count("pk"))
        .values_list("profile__zone_id", "total")
    )
    areas = Zone.objects.filter(
        level=ZoneLevel.QUARTIER, is_active=True, parent=city, pk__in=list(profile_rows)
    )
    stats = [(a, profile_rows[a.pk], offer_rows.get(a.pk, 0)) for a in areas]
    return stats, profile_rows.get(city.pk, 0)


def city_is_on_map(city) -> bool:
    return (
        city.level == ZoneLevel.VILLE_VILLAGE and city.is_active
        and mapped_profiles().filter(Q(zone=city) | Q(zone__parent=city)).exists()
    )
