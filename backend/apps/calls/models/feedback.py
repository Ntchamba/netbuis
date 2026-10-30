"""Retour après appel : l'appel a-t-il abouti ? Une ligne par appel, modifiable par l'appelant."""
from django.db import models

from apps.core.models.base import TimeStampedModel


class FeedbackOutcome(models.TextChoices):
    ANSWERED = "answered", "Appel abouti"
    NO_ANSWER = "no_answer", "Pas de réponse"
    WRONG_NUMBER = "wrong_number", "Mauvais numéro"


class CallFeedback(TimeStampedModel):
    call = models.OneToOneField(
        "calls.CallLog", verbose_name="appel", on_delete=models.CASCADE, related_name="feedback"
    )
    outcome = models.CharField("résultat", max_length=12, choices=FeedbackOutcome.choices)

    class Meta:
        verbose_name = "retour d'appel"
        verbose_name_plural = "retours d'appel"

    def __str__(self) -> str:
        return f"{self.get_outcome_display()} (appel #{self.call_id})"
