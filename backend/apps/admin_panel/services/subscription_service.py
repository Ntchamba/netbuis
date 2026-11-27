"""Abonnements vus par l'administration (T074c, lecture seule).

- Les profils visibles (actifs, propriétaire ni bloqué ni supprimé).
- Abonné : règle unique `business.services.subscription` (actif et non échu).
- Fort trafic : non abonné et appels des dernières 24 h > seuil `seuil_appels_abonnement`
  (même règle que la vue d'ensemble, `stats_service`).
- Le numéro n'est jamais en clair ici.

Accord d'un abonnement (T110, sans paiement) : `grant` crée UNE ligne `Subscription` (source
`manuel`, `granted_by` = l'administrateur) et l'audit `accord_abonnement` (motif obligatoire)
dans une seule transaction. Le profil est verrouillé le temps de la vérification, donc deux
accords simultanés ne peuvent pas créer deux abonnements actifs.
"""
from datetime import timedelta

from django.db import transaction
from django.db.models import Count, OuterRef, Q, Subquery
from django.utils import timezone
from rest_framework import status

from apps.admin_panel.models import AuditAction
from apps.admin_panel.services import audit_service
from apps.business.models import (
    BusinessProfile,
    BusinessStatus,
    Subscription,
    SubscriptionSource,
    SubscriptionStatus,
)
from apps.business.services.subscription import active_subscription_queryset, annotate_subscribed
from apps.core.exceptions import ApiError
from apps.core.models.platform_setting import SettingKey
from apps.core.services.settings_service import get_setting

from .stats_service import TRAFFIC_WINDOW

MIN_DAYS, MAX_DAYS = 1, 366
FILTERS = ("all", "subscribed", "unsubscribed", "high_traffic")


class InvalidSubscriptionFilter(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "invalid_filter"
    default_detail = "Filtre inconnu. Valeurs : all, subscribed, unsubscribed, high_traffic."


def list_queryset(kind="all", now=None):
    if kind not in FILTERS:
        raise InvalidSubscriptionFilter()
    now = now or timezone.now()
    since = now - TRAFFIC_WINDOW
    end = active_subscription_queryset(now).filter(profile=OuterRef("pk")).order_by("-end")
    qs = annotate_subscribed(
        BusinessProfile.objects.visible().select_related("owner", "zone"), now=now
    ).annotate(
        subscription_end=Subquery(end.values("end")[:1]),
        calls_last_day=Count(
            "call_logs", filter=Q(call_logs__created_at__gte=since, call_logs__created_at__lte=now)
        ),
    )
    if kind == "subscribed":
        qs = qs.filter(is_subscribed=True)
    elif kind == "unsubscribed":
        qs = qs.filter(is_subscribed=False)
    elif kind == "high_traffic":
        qs = qs.filter(is_subscribed=False, calls_last_day__gt=get_setting(
            SettingKey.SEUIL_APPELS_ABONNEMENT))
    return qs.order_by("-calls_last_day", "id")


class BusinessNotFound(ApiError):
    status_code = status.HTTP_404_NOT_FOUND
    default_code = "not_found"
    default_detail = "Compte business introuvable."


class BusinessNotActive(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "business_not_active"
    default_detail = "Seul un compte business actif peut recevoir un abonnement."


class AlreadySubscribed(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "already_subscribed"
    default_detail = "Ce compte a déjà un abonnement en cours."


def grant(admin, business_id: int, duration_days: int, reason: str, now=None) -> Subscription:
    """Accorde un abonnement manuel de `duration_days` jours, à partir de maintenant."""
    now = now or timezone.now()
    with transaction.atomic():
        profile = (
            BusinessProfile.objects.select_for_update(of=("self",))
            .select_related("owner")
            .filter(pk=business_id, owner__is_deleted=False)
            .first()
        )
        if profile is None:
            raise BusinessNotFound()
        if profile.status != BusinessStatus.ACTIVE or profile.owner.is_blocked \
                or not profile.owner.is_active:
            raise BusinessNotActive()
        if active_subscription_queryset(now).filter(profile=profile).exists():
            raise AlreadySubscribed()
        # Le motif est contrôlé AVANT toute écriture (record_action le revérifie).
        if not (reason or "").strip():
            raise audit_service.ReasonRequired()
        subscription = Subscription.objects.create(
            profile=profile, start=now, end=now + timedelta(days=duration_days),
            status=SubscriptionStatus.ACTIVE, source=SubscriptionSource.MANUAL,
            granted_by=admin,
        )
        audit_service.record_action(admin, AuditAction.ACCORD_ABONNEMENT, subscription, reason)
    subscription.profile = profile
    subscription.granted_by = admin
    return subscription
