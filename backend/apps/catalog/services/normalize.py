"""Normalisation d'un terme de recherche du catalogue (même règle que les noms enregistrés)."""
from apps.core.utils.text_normalize import normalize_text

MAX_QUERY_LENGTH = 100


def normalize_query(raw: str | None) -> str:
    """Terme normalisé (minuscules, sans accents ni ponctuation) ; vide si rien à chercher."""
    return normalize_text((raw or "").strip())
