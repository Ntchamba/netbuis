"""Appels Jitsi vers l'équipe NetBuis (D-25, docs/spec/APPELS_JITSI.md).

`CallSession` : un appel d'un utilisateur vers l'équipe. Le nom de salle (`room`) est SECRET :
il n'est jamais écrit dans un journal, ni dans un événement temps réel, ni dans une liste.
Aucun numéro de téléphone n'est stocké ici.
"""
import uuid

from django.conf import settings
from django.db import models
from django.db.models import Q

from apps.core.models.base import TimeStampedModel

from .call_log import BillingType


class SessionState(models.TextChoices):
    RINGING = "ringing", "Sonnerie"
    ANSWERED = "answered", "En cours"
    ENDED = "ended", "Terminé"
    MISSED = "missed", "Manqué"
    DECLINED = "declined", "Refusé"
    UNAVAILABLE = "unavailable", "Personne de disponible"
    CANCELLED = "cancelled", "Annulé par l'appelant"


ACTIVE_STATES = (SessionState.RINGING, SessionState.ANSWERED)


class EndReason(models.TextChoices):
    CALLER_HANGUP = "caller_hangup", "L'appelant a raccroché"
    AGENT_HANGUP = "agent_hangup", "L'agent a raccroché"
    CALLER_CANCEL = "caller_cancel", "L'appelant a annulé"
    TIMEOUT = "timeout", "Sonnerie expirée"
    ALL_DECLINED = "all_declined", "Tous les agents ont refusé"
    NO_AGENT = "no_agent", "Aucun agent disponible"
    TOO_LONG = "too_long", "Durée maximale atteinte"


class CallSession(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    caller = models.ForeignKey(
        settings.AUTH_USER_MODEL, verbose_name="appelant", on_delete=models.CASCADE,
        related_name="call_sessions",
    )
    business = models.ForeignKey(
        "business.BusinessProfile", verbose_name="commerce concerné", null=True, blank=True,
        on_delete=models.SET_NULL, related_name="call_sessions",
        help_text="Contexte seulement : le commerçant n'est jamais joint.",
    )
    room = models.CharField("salle (secrète)", max_length=64, unique=True, editable=False)
    state = models.CharField(
        "état", max_length=11, choices=SessionState.choices, default=SessionState.RINGING,
    )
    agent = models.ForeignKey(
        settings.AUTH_USER_MODEL, verbose_name="agent qui a répondu", null=True, blank=True,
        on_delete=models.SET_NULL, related_name="answered_call_sessions",
    )
    end_reason = models.CharField(
        "motif de fin", max_length=13, choices=EndReason.choices, blank=True, default="",
    )
    billing_type = models.CharField(
        "facturation", max_length=6, choices=BillingType.choices, default=BillingType.NONE
    )
    created_at = models.DateTimeField("création", auto_now_add=True)
    ringing_at = models.DateTimeField("début de sonnerie", null=True, blank=True)
    expires_at = models.DateTimeField("fin de sonnerie", null=True, blank=True)
    answered_at = models.DateTimeField("réponse", null=True, blank=True)
    ended_at = models.DateTimeField("fin", null=True, blank=True)

    class Meta:
        verbose_name = "session d'appel"
        verbose_name_plural = "sessions d'appel"
        ordering = ("-created_at", "-id")
        constraints = [
            # Une seule session active par appelant, garantie par la base (pas seulement le code).
            models.UniqueConstraint(
                fields=["caller"], condition=Q(state__in=["ringing", "answered"]),
                name="call_session_one_active_per_caller",
            ),
        ]
        indexes = [
            models.Index(fields=["caller", "created_at"]),
            models.Index(fields=["state", "expires_at"]),
        ]

    def __str__(self) -> str:
        return f"Session {self.id} ({self.state})"


class CallSessionDecline(TimeStampedModel):
    """Refus d'un agent : trace d'audit (qui, quand) et décompte « tous ont refusé »."""

    session = models.ForeignKey(
        CallSession, verbose_name="session", on_delete=models.CASCADE, related_name="declines"
    )
    agent = models.ForeignKey(
        settings.AUTH_USER_MODEL, verbose_name="agent", on_delete=models.CASCADE,
        related_name="call_declines",
    )

    class Meta:
        verbose_name = "refus d'appel"
        verbose_name_plural = "refus d'appel"
        constraints = [
            models.UniqueConstraint(fields=["session", "agent"], name="call_decline_unique"),
        ]


class AgentPresence(models.Model):
    """Présence d'un agent. « Disponible » = a choisi Disponible, a un flux temps réel ouvert
    et une activité plus récente que `AGENT_PRESENCE_TTL` secondes."""

    agent = models.OneToOneField(
        settings.AUTH_USER_MODEL, verbose_name="agent", on_delete=models.CASCADE,
        related_name="call_presence",
    )
    available = models.BooleanField("a choisi « Disponible »", default=False)
    open_streams = models.PositiveSmallIntegerField("flux ouverts", default=0)
    last_seen = models.DateTimeField("dernière activité", null=True, blank=True)

    class Meta:
        verbose_name = "présence d'agent"
        verbose_name_plural = "présences d'agents"
        indexes = [models.Index(fields=["available", "last_seen"])]

    def __str__(self) -> str:
        return f"Présence de l'agent {self.agent_id}"
