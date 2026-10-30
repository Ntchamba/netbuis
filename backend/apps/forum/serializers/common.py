"""Aides communes des sérialiseurs du forum. AUCUN numéro de téléphone n'en sort."""
import re

from apps.business.services.storage_service import StorageError, get_storage

_WORD = re.compile(r"[^\W_]+")


def initials(name: str) -> str:
    words = _WORD.findall(name or "")
    return "".join(word[0] for word in words[:2]).upper()


def public_url(key: str) -> str | None:
    if not key:
        return None
    try:
        return get_storage().public_url(key)
    except StorageError:
        return None


def short_name(name: str) -> str:
    """« Jeff Nguebou » -> « Jeff N. » : jamais le nom complet d'un simple compte."""
    words = (name or "").split()
    if not words:
        return "Utilisateur"
    if len(words) == 1:
        return words[0]
    return f"{words[0]} {words[1][0].upper()}."
