"""Règle unique « abonné » (T025b) : un profil est abonné si et seulement s'il a une ligne
`status="actif"` avec `start <= now < end`.

Tout le reste (plafonds T026, tri de la recherche T040, forum) passe par ces fonctions ; la règle
n'est écrite qu'ici, dans `active_subscription_condition`. Rien n'est modifié : un abonnement
échu est simplement « non abonné » (le passage à « expiré » est fait par une commande, T110).
"""
from django.db.models import Exists, OuterRef, Q, QuerySet
from django.utils import timezone

from apps.business.models import BusinessProfile, Subscription, SubscriptionStatus


def active_subscription_condition(now=None) -> Q:
    """La condition « actif et non échu », sur le modèle Subscription."""
    now = now or timezone.now()
    return Q(status=SubscriptionStatus.ACTIVE, start__lte=now, end__gt=now)


def active_subscription_queryset(now=None) -> QuerySet:
    """Les abonnements actifs et non échus."""
    return Subscription.objects.filter(active_subscription_condition(now))


def is_subscribed(profile, now=None) -> bool:
    """Vrai si le profil a un abonnement actif non échu. Faux pour `None`. Une requête."""
    if profile is None or profile.pk is None:
        return False
    return active_subscription_queryset(now).filter(profile_id=profile.pk).exists()


def subscribed_profiles(queryset=None, now=None) -> QuerySet:
    """Les profils abonnés, en SQL (sans doublon)."""
    queryset = BusinessProfile.objects.all() if queryset is None else queryset
    return queryset.filter(Exists(active_subscription_queryset(now).filter(profile=OuterRef("pk"))))


def annotate_subscribed(queryset, now=None, name="is_subscribed") -> QuerySet:
    """Ajoute un booléen `is_subscribed` (pour trier : `.order_by("-is_subscribed", …)`)."""
    return queryset.annotate(
        **{name: Exists(active_subscription_queryset(now).filter(profile=OuterRef("pk")))}
    )
