"""Chiffres du tableau de bord (T073, lecture seule).

- Fenêtres de 7 jours GLISSANTES : `[maintenant - 7 jours, maintenant]`, bornes incluses.
- « Comptes à fort trafic » : appels reçus pendant les dernières 24 h (glissantes) strictement
  supérieurs au seuil `seuil_appels_abonnement` (PlatformSetting), comptes business visibles
  (actifs, propriétaire ni bloqué ni supprimé) et non abonnés. Aucun numéro n'est lu.
- Un nombre de requêtes constant, quel que soit le volume des données.
- Revenus : les paiements ne sont pas faits ; la valeur est 0 et marquée `unavailable`.
"""
from datetime import timedelta

from django.db.models import Count, Q
from django.utils import timezone

from apps.accounts.models import User
from apps.business.models import BusinessProfile
from apps.business.services.subscription import annotate_subscribed, subscribed_profiles
from apps.calls.models import CallLog
from apps.core.models.platform_setting import SettingKey
from apps.core.services.settings_service import get_setting
from apps.geo.models import ZoneLevel
from apps.search.models import SearchLog

from . import request_service

WINDOW = timedelta(days=7)
TRAFFIC_WINDOW = timedelta(hours=24)
TRAFFIC_LIMIT = 10  # lignes de la liste « fort trafic »
CURRENCY = "FCFA"


def high_traffic_queryset(now, threshold):
    since = now - TRAFFIC_WINDOW
    return (
        annotate_subscribed(BusinessProfile.objects.visible(), now=now)
        .filter(is_subscribed=False)
        .annotate(calls_last_day=Count(
            "call_logs", filter=Q(call_logs__created_at__gte=since, call_logs__created_at__lte=now)
        ))
        .filter(calls_last_day__gt=threshold)
        .order_by("-calls_last_day", "id")
    )


def compute(now=None) -> dict:
    now = now or timezone.now()
    since = now - WINDOW
    visible = BusinessProfile.objects.visible()

    accounts = User.objects.filter(is_deleted=False).aggregate(
        total=Count("pk"), new=Count("pk", filter=Q(created_at__gte=since, created_at__lte=now)),
    )
    threshold = get_setting(SettingKey.SEUIL_APPELS_ABONNEMENT)
    traffic = high_traffic_queryset(now, threshold)

    return {
        "accounts_total": accounts["total"],
        "accounts_new_week": accounts["new"],
        "active_businesses": visible.count(),
        "neighborhoods_covered": visible.filter(zone__level=ZoneLevel.QUARTIER)
        .values("zone_id").distinct().count(),
        "pending_requests": request_service.pending_queryset().count(),
        "calls_week": CallLog.objects.filter(created_at__gte=since, created_at__lte=now).count(),
        "searches_week": SearchLog.objects.filter(
            created_at__gte=since, created_at__lte=now).count(),
        "subscribers": subscribed_profiles(visible, now=now).count(),
        "subscription_threshold": threshold,
        "high_traffic_count": traffic.count(),
        "high_traffic": [
            {"id": row.pk, "name": row.name, "calls_per_day": row.calls_last_day}
            for row in traffic[:TRAFFIC_LIMIT]
        ],
        "revenue_month": {"amount": 0, "currency": CURRENCY, "unavailable": True},
    }
