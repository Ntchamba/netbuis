"""Expiration des abonnements (T110).

Passe en `expire` les abonnements encore `actif` dont la fin est atteinte. Rien n'est supprimé :
seul le statut change, l'historique reste. Idempotente. Ce passage n'est qu'un rangement : un
abonnement échu est déjà « non abonné » pour `is_subscribed`, même avant la commande.
"""
from django.utils import timezone

from apps.business.models import Subscription, SubscriptionStatus


def expire_due_subscriptions(now=None) -> int:
    """Retourne le nombre d'abonnements passés en `expire`."""
    now = now or timezone.now()
    return Subscription.objects.filter(
        status=SubscriptionStatus.ACTIVE, end__lte=now
    ).update(status=SubscriptionStatus.EXPIRED, updated_at=now)
