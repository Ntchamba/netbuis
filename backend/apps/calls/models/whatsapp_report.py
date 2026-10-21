"""Signalement « ce numéro n'a pas WhatsApp » : un par compte et par commerce."""
from django.conf import settings
from django.db import models

from apps.core.models.base import TimeStampedModel


class WhatsAppReport(TimeStampedModel):
    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL, verbose_name="auteur", on_delete=models.CASCADE,
        related_name="whatsapp_reports",
    )
    profile = models.ForeignKey(
        "business.BusinessProfile", verbose_name="compte business", on_delete=models.CASCADE,
        related_name="whatsapp_reports",
    )
    reviewed = models.BooleanField(
        "examiné par un admin", default=False,
        help_text="Un signalement examiné ne compte plus pour le seuil de masquage.",
    )

    class Meta:
        verbose_name = "signalement WhatsApp"
        verbose_name_plural = "signalements WhatsApp"
        constraints = [
            models.UniqueConstraint(fields=["reporter", "profile"], name="whatsapp_report_unique"),
        ]
        indexes = [models.Index(fields=["profile", "reviewed"])]

    def __str__(self) -> str:
        return f"Signalement #{self.pk} sur le commerce #{self.profile_id}"
