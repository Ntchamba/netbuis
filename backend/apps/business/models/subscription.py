"""Subscription : abonnement d'un compte business (T025b), accordé à la main en v1.

L'abonnement ne conditionne JAMAIS la visibilité de base : il donne la priorité d'affichage, des
publications illimitées et des sous-catégories illimitées. Un abonnement expiré ne supprime rien.

Seuls les statuts `actif` et `expire` existent ici ; le statut « impayé » de la spec dépend du
paiement (reporté). Aucune valeur de paiement dans `source`.

La règle « abonné » (actif et non échu) vit à un seul endroit :
`business.services.subscription`.
"""
from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models

from apps.core.models.base import TimeStampedModel


class SubscriptionStatus(models.TextChoices):
    ACTIVE = "actif", "Actif"
    EXPIRED = "expire", "Expiré"


class SubscriptionSource(models.TextChoices):
    MANUAL = "manuel", "Accordé à la main"


class Subscription(TimeStampedModel):
    profile = models.ForeignKey(
        "business.BusinessProfile", verbose_name="compte business", on_delete=models.CASCADE,
        related_name="subscriptions",
    )
    start = models.DateTimeField("début")
    end = models.DateTimeField("fin")
    status = models.CharField(
        "statut", max_length=8, choices=SubscriptionStatus.choices,
        default=SubscriptionStatus.ACTIVE,
    )
    source = models.CharField(
        "source", max_length=8, choices=SubscriptionSource.choices,
        default=SubscriptionSource.MANUAL,
    )
    granted_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, verbose_name="accordé par", null=True, blank=True,
        on_delete=models.SET_NULL, related_name="+",
    )

    class Meta:
        verbose_name = "abonnement"
        verbose_name_plural = "abonnements"
        ordering = ["-end", "id"]
        indexes = [
            models.Index(fields=["profile", "status", "end"], name="business_sub_profile_st_end"),
        ]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(end__gt=models.F("start")),
                name="business_subscription_end_after_start",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.profile_id} : {self.get_status_display()} jusqu'au {self.end:%d/%m/%Y}"

    def clean(self):
        errors: dict[str, str] = {}
        if self.start is None:
            errors["start"] = "Le début est obligatoire."
        if self.end is None:
            errors["end"] = "La fin est obligatoire."
        if self.start is not None and self.end is not None and self.end <= self.start:
            errors["end"] = "La fin doit être après le début."
        if self.status not in SubscriptionStatus.values:
            errors["status"] = "Statut inconnu."
        if self.source not in SubscriptionSource.values:
            errors["source"] = "Source inconnue."
        if errors:
            raise ValidationError(errors)

    def save(self, *args, **kwargs):
        self.clean()
        super().save(*args, **kwargs)
