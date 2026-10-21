"""Abonnements vus par l'administration (T074c, lecture seule).

- Les profils visibles (actifs, propriétaire ni bloqué ni supprimé).
- Abonné : règle unique `business.services.subscription` (actif et non échu).
- Fort trafic : non abonné et appels des dernières 24 h > seuil `seuil_appels_abonnement`
  (même règle que la vue d'ensemble, `stats_service`).
- Le numéro n'est jamais en clair ici.
"""
from django.db.models import Count, OuterRef, Q, Subquery
from django.utils import timezone
from rest_framework import status

from apps.business.models import BusinessProfile
from apps.business.services.subscription import active_subscription_queryset, annotate_subscribed
from apps.core.exceptions import ApiError
from apps.core.models.platform_setting import SettingKey
from apps.core.services.settings_service import get_setting

from .stats_service import TRAFFIC_WINDOW

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
