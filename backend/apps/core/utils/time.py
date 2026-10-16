"""Fuseau du projet : Africa/Douala."""
from datetime import datetime
from zoneinfo import ZoneInfo

DOUALA = ZoneInfo("Africa/Douala")


def now_douala() -> datetime:
    return datetime.now(DOUALA)
