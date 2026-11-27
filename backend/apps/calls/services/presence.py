"""Présence des agents (D-25) : qui peut recevoir un appel maintenant.

Un agent est « disponible » s'il a choisi Disponible, a un flux temps réel ouvert, a eu une
activité (battement de cœur ou flux) depuis moins de `AGENT_PRESENCE_TTL` secondes, est
toujours un administrateur utilisable et possède le droit « répondre aux appels » (relu en
base à chaque décompte).
"""
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.db.models import F
from django.utils import timezone

from apps.accounts.models import User
from apps.admin_panel.services import rights_service
from apps.calls.models import AgentPresence


def _fresh_since(now=None):
    return (now or timezone.now()) - timedelta(seconds=settings.AGENT_PRESENCE_TTL)


def available_agents(now=None):
    """Administrateurs à qui l'appel peut sonner (queryset d'`User`, sans doublon)."""
    return User.objects.filter(
        is_admin=True, is_active=True, is_blocked=False, is_deleted=False,
        call_presence__available=True,
        call_presence__open_streams__gt=0,
        call_presence__last_seen__gte=_fresh_since(now),
        groups__name__in=rights_service.ADMIN_GROUPS,
        groups__permissions__codename=rights_service.REPONDRE_APPELS,
        groups__permissions__content_type__app_label=rights_service.APP_LABEL,
    ).distinct()


def has_available_agent(now=None) -> bool:
    return available_agents(now).exists()


def set_available(user, available: bool | None) -> AgentPresence:
    """Choix « Disponible / Indisponible » ; `None` = simple battement de cœur."""
    presence, _ = AgentPresence.objects.get_or_create(agent=user)
    presence.last_seen = timezone.now()
    fields = ["last_seen"]
    if available is not None:
        presence.available = available
        fields.append("available")
    presence.save(update_fields=fields)
    return presence


def open_stream(user) -> AgentPresence:
    """Un flux temps réel s'ouvre. Un compteur resté bloqué après un arrêt brutal est remis à
    zéro quand l'activité est périmée."""
    now = timezone.now()
    AgentPresence.objects.get_or_create(agent=user)
    with transaction.atomic():
        presence = AgentPresence.objects.select_for_update().get(agent=user)
        if presence.last_seen is None or presence.last_seen < _fresh_since(now):
            presence.open_streams = 0
        presence.open_streams += 1
        presence.last_seen = now
        presence.save(update_fields=["open_streams", "last_seen"])
    return presence


def close_stream(user_id: int) -> None:
    AgentPresence.objects.filter(agent_id=user_id, open_streams__gt=0).update(
        open_streams=F("open_streams") - 1
    )


def heartbeat(user_id: int) -> None:
    AgentPresence.objects.filter(agent_id=user_id).update(last_seen=timezone.now())
