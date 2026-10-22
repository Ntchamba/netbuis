"""Contacts WhatsApp (zone sensible) et erreurs d'appel communes.

D-25 : l'appel téléphonique au commerçant n'existe plus (les appels passent par Jitsi vers
l'équipe, voir `session_service`). Reste le lien WhatsApp : le numéro n'est lu qu'ici, à la
toute fin, pour construire le lien `wa.me` ; il n'est mis dans aucun message d'erreur ni
journal.
"""
from django.db import transaction
from django.db.models import F
from django.utils import timezone
from rest_framework import status

from apps.accounts.models import User
from apps.business.models import BusinessProfile, BusinessStatus
from apps.calls.models import BillingType, CallChannel, CallLog
from apps.calls.services.rate_limit import is_whatsapp_rate_limited
from apps.calls.services.whatsapp_service import build_wa_url, prefilled_message
from apps.core.exceptions import ApiError


class CallRefused(ApiError):
    """Refus ; `code` appartient à la liste fermée de l'API. `extra` : champs ajoutés à la
    réponse (jamais de numéro, de salle ni de jeton)."""

    def __init__(self, code: str, message: str, status_code: int, extra: dict | None = None):
        super().__init__(message, code=code)
        self.status_code = status_code
        self.extra = extra or {}


def not_authenticated() -> CallRefused:
    return CallRefused(
        "NOT_AUTHENTICATED", "Veuillez vous connecter.", status.HTTP_401_UNAUTHORIZED
    )


def account_blocked() -> CallRefused:
    return CallRefused(
        "ACCOUNT_BLOCKED", "Ce compte est bloqué. Contactez le support.", status.HTTP_403_FORBIDDEN
    )


def business_not_active() -> CallRefused:
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


def open_whatsapp(user, business_id: int, platform: str) -> dict:
    """Retourne {"call_id", "wa_url"} ou lève CallRefused."""
    if not (user and user.is_authenticated):
        raise not_authenticated()
    if not user.can_login():
        raise account_blocked()
    with transaction.atomic():
        # Verrou de la ligne appelant : sérialise les décomptes de la limite anti-aspiration.
        caller = User.objects.select_for_update().get(pk=user.pk)
        if not caller.can_login():
            raise account_blocked()
        profile = (
            BusinessProfile.objects.select_related("owner").filter(pk=business_id).first()
        )
        if profile is None:
            raise business_not_active()
        if profile.owner_id == caller.pk:
            raise CallRefused(
                "OWN_BUSINESS", "Vous ne pouvez pas contacter votre propre commerce.",
                status.HTTP_403_FORBIDDEN,
            )
        if not _owner_usable(profile.owner):
            raise account_blocked()
        if profile.status != BusinessStatus.ACTIVE:
            raise business_not_active()
        ensure_channel_available(profile, CallChannel.WHATSAPP)
        if is_whatsapp_rate_limited(caller, timezone.now()):
            raise CallRefused(
                "RATE_LIMITED", "Trop d'appels en peu de temps. Réessayez plus tard.",
                status.HTTP_429_TOO_MANY_REQUESTS,
            )
        log = CallLog.objects.create(
            caller=caller, profile=profile, channel=CallChannel.WHATSAPP, platform=platform,
            operator="", billing_type=BillingType.NONE,
        )
        BusinessProfile.objects.filter(pk=profile.pk).update(calls_count=F("calls_count") + 1)
        phone = profile.phone_anchor
        name = profile.name
    return {"call_id": log.pk, "wa_url": build_wa_url(phone, prefilled_message(name))}
