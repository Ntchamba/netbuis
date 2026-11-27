"""Point d'accroche du quota d'appels (D-29, V08 reporté).

UNE fonction décide si un appelant peut lancer un appel vers l'équipe. Les paiements sont
reportés : rien n'est débité et aucun portefeuille n'est lu. Quand Jeff aura tranché la
question Q7 (ce qu'achète un pack de crédits), seul ce fichier changera.
"""
from django.conf import settings
from django.utils import timezone
from rest_framework import status

from apps.calls.models import BillingType, CallSession
from apps.calls.services.call_service import CallRefused
from apps.calls.services.rate_limit import is_session_rate_limited

# Valeur technique d'essai, active seulement si CREDITS_ENABLED (D-03). À fixer par Jeff avec
# les crédits (V08) ; le portefeuille n'existe pas encore, donc pas d'achat au-delà.
FREE_CALLS_PER_DAY = 3


def caller_may_start_call(user, now=None) -> str:
    """Retourne le type de facturation de l'appel (`none` ou `free`) ou lève CallRefused (429).

    L'appelant doit avoir sa ligne `User` verrouillée par la transaction en cours.
    """
    now = now or timezone.now()
    if is_session_rate_limited(user, now):
        raise CallRefused(
            "RATE_LIMITED", "Trop d'appels en peu de temps. Réessayez plus tard.",
            status.HTTP_429_TOO_MANY_REQUESTS,
        )
    if not settings.CREDITS_ENABLED:
        return BillingType.NONE
    today = CallSession.objects.filter(
        caller=user, billing_type=BillingType.FREE,
        created_at__gte=now.replace(hour=0, minute=0, second=0, microsecond=0),
    ).count()
    if today >= FREE_CALLS_PER_DAY:
        # Pas de portefeuille tant que les paiements sont reportés : rien à débiter.
        raise CallRefused(
            "RATE_LIMITED", "Vous avez utilisé vos appels gratuits du jour. Réessayez demain.",
            status.HTTP_429_TOO_MANY_REQUESTS,
        )
    return BillingType.FREE
