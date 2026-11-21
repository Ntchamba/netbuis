"""Signalisation WebRTC (D-31, docs/spec/APPELS_WEBRTC.md).

`CallSignal` : un message d'établissement de connexion (offre, réponse, candidat, fin) échangé
entre l'appelant et l'agent. Conservé le temps de l'appel (l'agent n'est pas encore là pendant la
sonnerie), supprimé à la fin de la session. Le contenu n'est jamais journalisé.
Aucun numéro de téléphone n'y passe.
"""
from django.db import models

from .session import CallSession


class SignalKind(models.TextChoices):
    OFFER = "offer", "Offre"
    ANSWER = "answer", "Réponse"
    CANDIDATE = "candidate", "Candidat ICE"
    BYE = "bye", "Fin"


class SignalRole(models.TextChoices):
    CALLER = "caller", "Appelant"
    AGENT = "agent", "Agent"


MAX_SIGNAL_BYTES = 16 * 1024
MAX_SIGNALS_PER_SESSION = 200


class CallSignal(models.Model):
    session = models.ForeignKey(
        CallSession, verbose_name="session", on_delete=models.CASCADE, related_name="signals"
    )
    from_role = models.CharField("émetteur", max_length=6, choices=SignalRole.choices)
    kind = models.CharField("type", max_length=9, choices=SignalKind.choices)
    data = models.JSONField("contenu", default=dict)
    created_at = models.DateTimeField("création", auto_now_add=True)

    class Meta:
        verbose_name = "signal d'appel"
        verbose_name_plural = "signaux d'appel"
        ordering = ("id",)
        indexes = [models.Index(fields=["session", "id"], name="calls_signal_session_idx")]

    def __str__(self) -> str:
        return f"Signal {self.pk} ({self.kind})"
