"""Normalisation de la requête écrite (T040) : minuscules, sans accents ni ponctuation, sans les
petits mots « du, de, des, un… ». Même règle de base que les noms du catalogue
(`apps.core.utils.text_normalize`)."""
from apps.catalog.services.normalize import MAX_QUERY_LENGTH
from apps.catalog.services.normalize import normalize_query as _base_normalize

STOPWORDS = frozenset({"du", "de", "des", "un", "une", "le", "la", "les", "l", "d"})


def normalize_search_term(raw: str | None) -> str:
    """Terme de recherche normalisé ; chaîne vide s'il n'y a rien à chercher.

    Si la saisie n'est faite QUE de petits mots (« de »), on la garde telle quelle plutôt que de
    la transformer en recherche vide (qui listerait tout)."""
    text = _base_normalize((raw or "")[:MAX_QUERY_LENGTH])
    words = text.split()
    kept = [word for word in words if word not in STOPWORDS]
    return " ".join(kept) if kept else text
