"""CallLog : une ligne par numéro délivré (appel ou WhatsApp).

Aucun numéro de téléphone n'est stocké ici : il se lit sur le profil (`phone_anchor`) au
moment de répondre et nulle part ailleurs.
"""
from django.conf import settings
from django.db import models

from apps.core.models.base import TimeStampedModel


class CallChannel(models.TextChoices):
    CALL = "call", "Appel"
    WHATSAPP = "whatsapp", "WhatsApp"


class Platform(models.TextChoices):
    ANDROID = "android", "Android"
    IOS = "ios", "iOS"


class Operator(models.TextChoices):
    ORANGE = "orange", "Orange"
    MTN = "mtn", "MTN"


class BillingType(models.TextChoices):
    FREE = "free", "Gratuit"
    CREDIT = "credit", "Crédit"
    NONE = "none", "Aucun"


class CallLog(TimeStampedModel):
    """`created_at` est la date de l'appel."""

    caller = models.ForeignKey(
        settings.AUTH_USER_MODEL, verbose_name="appelant", on_delete=models.CASCADE,
        related_name="call_logs",
    )
    profile = models.ForeignKey(
        "business.BusinessProfile", verbose_name="compte business", on_delete=models.CASCADE,
        related_name="call_logs",
    )
    channel = models.CharField("canal", max_length=8, choices=CallChannel.choices)
    platform = models.CharField("plateforme", max_length=7, choices=Platform.choices)
    operator = models.CharField(
        "opérateur", max_length=6, choices=Operator.choices, blank=True, default=""
    )
    billing_type = models.CharField(
        "facturation", max_length=6, choices=BillingType.choices, default=BillingType.NONE
    )

    class Meta:
        verbose_name = "appel"
        verbose_name_plural = "appels"
        ordering = ("-created_at", "-id")
        indexes = [models.Index(fields=["caller", "created_at"])]

    def __str__(self) -> str:
        return f"{self.get_channel_display()} #{self.pk}"
