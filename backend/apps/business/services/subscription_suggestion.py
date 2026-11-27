"""Proposition d'abonnement (T110).

Vrai seulement si le commerce n'est PAS abonné (`is_subscribed`) et que le nombre d'appels reçus
aujourd'hui dépasse STRICTEMENT `seuil_appels_abonnement` (PlatformSetting, D-11). « Aujourd'hui » =
le jour calendaire du fuseau du projet (Africa/Douala). Une ligne de CallLog = un numéro délivré
(appel ou WhatsApp), comme dans les statistiques de l'administration. Ne bloque jamais un appel.
"""
from datetime import datetime, time, timedelta

from django.utils import timezone

from apps.business.services.subscription import is_subscribed
from apps.calls.models import CallLog
from apps.core.models.platform_setting import SettingKey
from apps.core.services.settings_service import get_setting


def calls_received_today(profile, now=None) -> int:
    now = timezone.localtime(now or timezone.now())
    start = timezone.make_aware(datetime.combine(now.date(), time.min), now.tzinfo)
    return CallLog.objects.filter(
        profile=profile, created_at__gte=start, created_at__lt=start + timedelta(days=1)
    ).count()


def suggest_subscription(profile, now=None) -> bool:
    if is_subscribed(profile, now):
        return False
    return calls_received_today(profile, now) > get_setting(SettingKey.SEUIL_APPELS_ABONNEMENT)
