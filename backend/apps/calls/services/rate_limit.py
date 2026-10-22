"""Limites anti-abus (D-05) : N par minute et M par jour, par compte.

Deux décomptes distincts : les sessions d'appel vers l'équipe (`CallSession`) et les liens
WhatsApp (`CallLog`, qui délivrent un numéro). Dans les deux cas l'appelant doit avoir sa ligne
`User` verrouillée par la transaction en cours pour que deux requêtes simultanées ne passent
pas toutes les deux.
"""
from datetime import timedelta

from django.utils import timezone

from apps.calls.models import CallLog, CallSession
from apps.core.models.platform_setting import SettingKey
from apps.core.services.settings_service import get_setting

MINUTE = timedelta(minutes=1)
DAY = timedelta(days=1)


def _over_limit(rows, now) -> bool:
    if rows.filter(created_at__gt=now - MINUTE).count() >= get_setting(
        SettingKey.LIMITE_APPELS_PAR_MINUTE
    ):
        return True
    return rows.filter(created_at__gt=now - DAY).count() >= get_setting(
        SettingKey.LIMITE_APPELS_PAR_JOUR
    )


def is_whatsapp_rate_limited(user, now=None) -> bool:
    return _over_limit(CallLog.objects.filter(caller=user), now or timezone.now())


def is_session_rate_limited(user, now=None) -> bool:
    """Toutes les sessions comptent, même celles restées sans agent disponible."""
    return _over_limit(CallSession.objects.filter(caller=user), now or timezone.now())
