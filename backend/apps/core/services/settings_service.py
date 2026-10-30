"""Lecture des réglages de plateforme (T008b), avec un cache court.

Le cache par défaut est LocMem, donc propre à chaque processus : l'écriture vide le
cache du processus qui écrit ; les autres processus (autres workers) relisent la base
au plus tard après CACHE_TIMEOUT secondes.
"""
from django.core.cache import cache

from apps.core.models.platform_setting import (
    DEFAULTS,
    PlatformSetting,
    SettingKey,
    UnknownSettingError,
)

CACHE_TIMEOUT = 60  # secondes
CACHE_PREFIX = "platform_setting:"


def cache_key(key: str) -> str:
    return f"{CACHE_PREFIX}{key}"


def get_setting(key: str) -> int:
    """Valeur entière du réglage `key` ; défaut de `DEFAULTS` si aucune ligne n'existe."""
    if key not in SettingKey.values:
        raise UnknownSettingError(key)
    value = cache.get(cache_key(key))
    if value is None:
        stored = PlatformSetting.objects.filter(key=key).values_list("value", flat=True).first()
        value = int(stored) if stored is not None else DEFAULTS[key]
        cache.set(cache_key(key), value, CACHE_TIMEOUT)
    return value


def invalidate_setting(key: str) -> None:
    cache.delete(cache_key(key))
