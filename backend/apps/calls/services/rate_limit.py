"""Limite anti-aspiration des numéros (D-05) : N par minute et M par jour, par compte.

Les deux canaux (appel et WhatsApp) comptent : tous deux délivrent le numéro. Le décompte
se fait sur le journal `CallLog` ; l'appelant doit avoir sa ligne `User` verrouillée par la
transaction en cours pour que deux requêtes simultanées ne passent pas toutes les deux.
"""
from datetime import timedelta

from django.utils import timezone

from apps.calls.models import CallLog
from apps.core.models.platform_setting import SettingKey
from apps.core.services.settings_service import get_setting

MINUTE = timedelta(minutes=1)
DAY = timedelta(days=1)


def is_rate_limited(user, now=None) -> bool:
    now = now or timezone.now()
    logs = CallLog.objects.filter(caller=user)
    if logs.filter(created_at__gt=now - MINUTE).count() >= get_setting(
        SettingKey.LIMITE_APPELS_PAR_MINUTE
    ):
        return True
    return logs.filter(created_at__gt=now - DAY).count() >= get_setting(
        SettingKey.LIMITE_APPELS_PAR_JOUR
    )
