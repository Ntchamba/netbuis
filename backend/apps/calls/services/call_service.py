"""Lancer un appel (zone sensible) : contrôles, journal, puis numéro.

Le numéro (`phone_anchor`) n'est lu qu'ici, à la toute fin, et renvoyé à l'appelant. Il n'est
mis dans aucun message d'erreur ni journal.
"""
from django.conf import settings
from django.db import transaction
from django.db.models import F
from django.utils import timezone
from rest_framework import status

from apps.accounts.models import User
from apps.business.models import BusinessProfile, BusinessStatus
from apps.calls.models import BillingType, CallChannel, CallLog
from apps.calls.services.rate_limit import is_rate_limited
from apps.core.exceptions import ApiError

# Valeur technique d'essai, active seulement si CREDITS_ENABLED (D-03). À fixer par Jeff avec
# les crédits (V08) ; le portefeuille n'existe pas encore, donc pas d'achat au-delà.
FREE_CALLS_PER_DAY = 3


class CallRefused(ApiError):
    """Refus d'un lancement d'appel ; `code` appartient à la liste fermée de l'API."""

    def __init__(self, code: str, message: str, status_code: int):
        super().__init__(message, code=code)
        self.status_code = status_code


def not_authenticated() -> CallRefused:
    return CallRefused(
        "NOT_AUTHENTICATED", "Veuillez vous connecter.", status.HTTP_401_UNAUTHORIZED
    )


def _account_blocked() -> CallRefused:
    return CallRefused(
        "ACCOUNT_BLOCKED", "Ce compte est bloqué. Contactez le support.", status.HTTP_403_FORBIDDEN
    )


def _not_active() -> CallRefused:
    return CallRefused(
        "BUSINESS_NOT_ACTIVE", "Ce commerce n'est pas disponible.", status.HTTP_404_NOT_FOUND
    )


def ensure_channel_available(profile, channel: str) -> None:
    """WhatsApp désactivé pour ce commerce (signalements ou choix du commerçant)."""
    if channel == CallChannel.WHATSAPP and not profile.whatsapp_available:
        raise CallRefused(
            "CHANNEL_UNAVAILABLE", "WhatsApp n'est pas disponible pour ce commerce.",
            status.HTTP_409_CONFLICT,
        )


def _owner_usable(owner) -> bool:
    return owner.is_active and not owner.is_blocked and not owner.is_deleted


def _billing_type(user, channel: str, now) -> str:
    """`none` sans crédits ; avec crédits, seuls les appels comptent pour le quota."""
    if not settings.CREDITS_ENABLED or channel != CallChannel.CALL:
        return BillingType.NONE
    today = CallLog.objects.filter(
        caller=user, channel=CallChannel.CALL, billing_type=BillingType.FREE,
        created_at__gte=now.replace(hour=0, minute=0, second=0, microsecond=0),
    ).count()
    if today >= FREE_CALLS_PER_DAY:
        # Pas de portefeuille tant que les paiements sont reportés : rien à débiter.
        raise CallRefused(
            "RATE_LIMITED", "Vous avez utilisé vos appels gratuits du jour. Réessayez demain.",
            status.HTTP_429_TOO_MANY_REQUESTS,
        )
    return BillingType.FREE


def initiate_call(user, business_id: int, channel: str, platform: str, operator: str = "") -> dict:
    """Retourne {"call_id", "phone"} ou lève CallRefused."""
    if not (user and user.is_authenticated):
        raise not_authenticated()
    if not user.can_login():
        raise _account_blocked()
    with transaction.atomic():
        # Verrou de la ligne appelant : sérialise les décomptes de la limite anti-aspiration.
        caller = User.objects.select_for_update().get(pk=user.pk)
        if not caller.can_login():
            raise _account_blocked()
        profile = (
            BusinessProfile.objects.select_related("owner").filter(pk=business_id).first()
        )
        if profile is None:
            raise _not_active()
        if profile.owner_id == caller.pk:
            raise CallRefused(
                "OWN_BUSINESS", "Vous ne pouvez pas appeler votre propre commerce.",
                status.HTTP_403_FORBIDDEN,
            )
        if not _owner_usable(profile.owner):
            raise _account_blocked()
        if profile.status != BusinessStatus.ACTIVE:
            raise _not_active()
        ensure_channel_available(profile, channel)
        now = timezone.now()
        if is_rate_limited(caller, now):
            raise CallRefused(
                "RATE_LIMITED", "Trop d'appels en peu de temps. Réessayez plus tard.",
                status.HTTP_429_TOO_MANY_REQUESTS,
            )
        billing = _billing_type(caller, channel, now)
        log = CallLog.objects.create(
            caller=caller, profile=profile, channel=channel, platform=platform,
            operator=operator or "", billing_type=billing,
        )
        BusinessProfile.objects.filter(pk=profile.pk).update(calls_count=F("calls_count") + 1)
        phone = profile.phone_anchor
    return {"call_id": log.pk, "phone": phone}
