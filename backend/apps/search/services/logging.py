"""Journal des recherches (T040). Jamais le compte ni le numéro : un hachage seulement."""
import hashlib
import hmac

from django.conf import settings

from apps.search.models import SearchLog, SearchMode


def hash_account(user) -> str:
    """HMAC-SHA256 (clé = clé secrète du serveur) de l'identifiant du compte ; vide sans compte.

    Stable : le même compte donne toujours le même hachage (pour compter des comptes distincts),
    mais on ne peut pas remonter au compte ni au numéro sans la clé du serveur."""
    pk = getattr(user, "pk", None)
    if pk is None:
        return ""
    digest = hmac.new(
        settings.SECRET_KEY.encode(), f"search-account:{pk}".encode(), hashlib.sha256
    )
    return digest.hexdigest()


def log_search(term: str, *, zone=None, results_count: int, user=None,
               mode: str = SearchMode.TEXT) -> SearchLog | None:
    """Enregistre la recherche. Un terme vide n'est pas journalisé (retourne None)."""
    if not term:
        return None
    return SearchLog.objects.create(
        term=term, mode=mode, zone=zone, results_count=results_count,
        account_hash=hash_account(user),
    )
