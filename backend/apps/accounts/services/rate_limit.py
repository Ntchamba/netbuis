"""Limites par numéro : 3 demandes de code par 10 minutes ; blocage 1 heure après 5 codes faux.

Connexion administrateur : 5 essais ratés par IP sur 15 minutes (fin du fichier).

Les limites par IP des codes SMS sont les throttles DRF `OtpRateThrottle` et `OtpVerifyRateThrottle`
(apps.core.throttling).
"""
import math
from datetime import timedelta

from django.db import connection, transaction
from django.db.models import F, Max, Sum
from django.utils import timezone

from apps.accounts.models import AdminLoginAttempt, OtpCode

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


# --- Connexion administrateur : 5 essais ratés par IP sur 15 minutes (T007) ---------------
# Un essai est RÉSERVÉ (ligne verrouillée en base) avant d'évaluer le mot de passe :
# même en simultané, au plus 5 mots de passe sont évalués par fenêtre. Une connexion
# réussie rend sa place ; au-delà de 5, 429 + Retry-After jusqu'à la fin de la fenêtre,
# même avec le bon mot de passe. La fenêtre s'ouvre au premier essai compté.
ADMIN_LOGIN_MAX_FAILURES = 5
ADMIN_LOGIN_WINDOW = timedelta(minutes=15)


def admin_login_reserve(ip: str) -> int:
    """Réserve un essai pour cette IP ; renvoie 0 si accordé, sinon les secondes à attendre."""
    now = timezone.now()
    with transaction.atomic():
        # Ligne créée si absente, sans conflit entre requêtes simultanées.
        AdminLoginAttempt.objects.bulk_create(
            [AdminLoginAttempt(ip=ip, window_end=now)], ignore_conflicts=True
        )
        row = AdminLoginAttempt.objects.select_for_update().get(ip=ip)
        if row.window_end <= now or row.failures == 0:
            row.failures, row.window_end = 0, now + ADMIN_LOGIN_WINDOW
        if row.failures >= ADMIN_LOGIN_MAX_FAILURES:
            return max(1, math.ceil((row.window_end - now).total_seconds()))
        row.failures += 1
        row.save(update_fields=["failures", "window_end"])
    return 0


def admin_login_release(ip: str) -> None:
    """Connexion réussie : la place réservée est rendue (seuls les échecs comptent)."""
    AdminLoginAttempt.objects.filter(ip=ip, failures__gt=0).update(failures=F("failures") - 1)
