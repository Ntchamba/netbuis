"""Seuil et classement des tendances (T104). Fonctions pures, sans base de données.

Le seuil évite les faux classements : un produit ou un commerce n'est classé que s'il a au
moins `min_hits` recherches (ou contacts) venant d'au moins `min_accounts` comptes distincts.
Les valeurs viennent de PlatformSetting (jamais écrites en dur ici).
"""
from dataclasses import dataclass

MAX_ENTRIES = 10


@dataclass(frozen=True)
class Candidate:
    key: int  # identifiant du produit ou du commerce
    hits: int
    accounts: int
    label: str  # nom, pour départager de façon stable


def passes_threshold(hits: int, accounts: int, *, min_hits: int, min_accounts: int) -> bool:
    return hits >= min_hits and accounts >= min_accounts


def rank(candidates, *, min_hits: int, min_accounts: int, limit: int = MAX_ENTRIES) -> list:
    """Candidats qui passent le seuil, du plus au moins sollicité, au plus `limit`.
    Égalité : plus de comptes d'abord, puis ordre alphabétique, puis identifiant."""
    kept = [c for c in candidates
            if passes_threshold(c.hits, c.accounts, min_hits=min_hits, min_accounts=min_accounts)]
    kept.sort(key=lambda c: (-c.hits, -c.accounts, c.label, c.key))
    return kept[:limit]
