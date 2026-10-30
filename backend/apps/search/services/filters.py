"""Filtres de la recherche (T040) : zone (ville, quartier…) et secteur.

La visibilité (actif, ni bloqué ni supprimé) n'est PAS écrite ici : elle vient de
`BusinessProfile.objects.visible()`, la seule définition.
"""
from apps.catalog.models import Sector
from apps.geo.models import Zone


def zone_parents() -> dict:
    """`{id de zone: id du parent}` pour toute la hiérarchie (une requête)."""
    return dict(Zone.objects.values_list("pk", "parent_id"))


def zone_subtree_ids(zone, parents: dict) -> set:
    """La zone et toutes celles qu'elle contient (quartiers d'une ville, villes d'un
    département…)."""
    children: dict = {}
    for pk, parent_id in parents.items():
        children.setdefault(parent_id, []).append(pk)
    found = {zone.pk}
    pending = [zone.pk]
    while pending:
        for child in children.get(pending.pop(), []):
            if child not in found:
                found.add(child)
                pending.append(child)
    return found


def resolve_sector(sector):
    """Un secteur donné par instance, par `code` stable ou par identifiant ; `None` si vide ;
    `False` si inconnu (la recherche renvoie alors zéro résultat plutôt que tout)."""
    if sector in (None, ""):
        return None
    if isinstance(sector, Sector):
        return sector
    lookup = {"pk": sector} if isinstance(sector, int) else {"code": str(sector)}
    return Sector.objects.filter(**lookup).first() or False


def apply_filters(queryset, *, zone_ids=None, sector=None):
    """Restreint un queryset de profils à la zone (sous-arbre) et au secteur."""
    if zone_ids is not None:
        queryset = queryset.filter(zone_id__in=zone_ids)
    if sector is False:
        return queryset.none()
    if sector is not None:
        queryset = queryset.filter(secteur=sector)
    return queryset
