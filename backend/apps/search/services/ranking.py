"""Classement des résultats (T040).

Ordre : abonnés actifs d'abord, puis pertinence (par paliers), puis proximité de la zone choisie,
puis pertinence fine, puis identifiant (ordre stable). Les non-abonnés restent toujours listés :
l'abonnement ne fait que remonter une fiche, il ne conditionne jamais la visibilité.
"""
from dataclasses import dataclass

TIER_COUNT = 4  # palier = partie entière de score × 4 : 0,3-0,5 → 1 ; … ; 1,0 → 4


@dataclass(frozen=True)
class Hit:
    profile_id: int
    score: float  # pertinence 0..1 (0 si aucun terme : liste de la zone)
    subscribed: bool
    proximity: int  # 0 = même zone ; plus grand = plus loin


def relevance_tier(score: float) -> int:
    return int(score * TIER_COUNT + 1e-9)


def zone_distance(zone_id, near_id, parents: dict) -> int:
    """Nombre de pas dans la hiérarchie entre deux zones, via leur plus proche ancêtre commun.
    0 si la même zone ; 0 aussi quand aucune zone de référence n'est choisie."""
    if near_id is None or zone_id is None:
        return 0
    near_path = {}
    node, steps = near_id, 0
    while node is not None and node not in near_path:
        near_path[node] = steps
        node, steps = parents.get(node), steps + 1
    node, steps = zone_id, 0
    seen = set()
    while node is not None and node not in seen:
        if node in near_path:
            return steps + near_path[node]
        seen.add(node)
        node, steps = parents.get(node), steps + 1
    return steps + len(near_path)  # hiérarchies sans ancêtre commun : très loin


def sort_key(hit: Hit):
    return (not hit.subscribed, -relevance_tier(hit.score), hit.proximity, -hit.score,
            hit.profile_id)


def rank(hits) -> list:
    return sorted(hits, key=sort_key)
