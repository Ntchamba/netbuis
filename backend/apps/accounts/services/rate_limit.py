"""Limites par numéro : 3 demandes de code par 10 minutes ; blocage 1 heure après 5 codes faux.

Les limites par IP sont les throttles DRF `OtpRateThrottle` et `OtpVerifyRateThrottle`
(apps.core.throttling).
"""
import math
from datetime import timedelta

from django.db import connection
from django.db.models import Max, Sum
from django.utils import timezone

from apps.accounts.models import OtpCode

PHONE_MAX_REQUESTS = 3
PHONE_WINDOW = timedelta(minutes=10)
PHONE_BLOCK = timedelta(hours=1)
PHONE_MAX_WRONG = 5  # codes faux par numéro sur la dernière heure, tous codes confondus


def lock_phone(phone: str) -> None:
    """Verrou PostgreSQL sur ce numéro, libéré à la fin de la transaction en cours.

    Deux demandes simultanées pour le même numéro passent l'une après l'autre :
    le comptage et la création du code ne peuvent pas se croiser.
    La clé du verrou est le numéro E.164 sans « + » (12 chiffres, tient dans un bigint).
    """
    with connection.cursor() as cursor:
        cursor.execute("SELECT pg_advisory_xact_lock(%s)", [int(phone.lstrip("+"))])


def phone_retry_after(phone: str) -> int:
    """Secondes à attendre avant une nouvelle demande pour ce numéro (0 = autorisé)."""
    now = timezone.now()
    recent = list(
        OtpCode.objects.filter(phone=phone, created_at__gt=now - PHONE_WINDOW)
        .order_by("-created_at")
        .values_list("created_at", flat=True)[:PHONE_MAX_REQUESTS]
    )
    if len(recent) < PHONE_MAX_REQUESTS:
        return 0
    # La plus ancienne des 3 dernières demandes sort de la fenêtre à cet instant.
    return math.ceil((recent[-1] + PHONE_WINDOW - now).total_seconds())


def phone_wrong_codes(phone: str) -> int:
    """Codes faux saisis pour ce numéro sur la dernière heure, tous codes confondus.

    Redemander un code ne remet donc pas le compteur à zéro.
    """
    since = timezone.now() - PHONE_BLOCK
    total = OtpCode.objects.filter(phone=phone, created_at__gt=since).aggregate(
        total=Sum("attempts")
    )["total"]
    return total or 0


def phone_blocked_for(phone: str) -> int:
    """Secondes de blocage restantes pour ce numéro après 5 codes faux (0 = pas bloqué)."""
    now = timezone.now()
    until = OtpCode.objects.filter(phone=phone, blocked_until__gt=now).aggregate(
        until=Max("blocked_until")
    )["until"]
    return math.ceil((until - now).total_seconds()) if until else 0
