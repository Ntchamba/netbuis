"""Réglages de plateforme modifiables sans nouvelle version (T008b).

Les clés et leurs valeurs par défaut sont déclarées ICI et nulle part ailleurs
(`SettingKey` + `DEFAULTS`). Une ligne absente de la table = valeur par défaut.
Lecture : `apps.core.services.settings_service.get_setting(key)`.
"""
from decimal import Decimal

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator
from django.db import models

from .base import TimeStampedModel


class SettingKey(models.TextChoices):
    PLAFOND_SOUS_CATEGORIES_NON_ABONNE = (
        "plafond_sous_categories_non_abonne",
        "Plafond de sous-catégories sans abonnement",
    )
    PLAFOND_PUBLICATIONS_NON_ABONNE = (
        "plafond_publications_non_abonne",
        "Plafond de publications actives sans abonnement",
    )
    LIMITE_APPELS_PAR_MINUTE = (
        "limite_appels_par_minute",
        "Limite d'appels par minute et par compte",
    )
    LIMITE_APPELS_PAR_JOUR = "limite_appels_par_jour", "Limite d'appels par jour et par compte"
    SEUIL_APPELS_ABONNEMENT = (
        "seuil_appels_abonnement",
        "Seuil d'appels quotidiens qui fait proposer l'abonnement",
    )


# Valeurs par défaut : D-12 (plafonds 3 et 5), D-05 (5/min, 50/jour),
# D-11 (seuil 10 = valeur technique d'essai, à fixer par Jeff avant la mise en service).
DEFAULTS: dict[str, int] = {
    SettingKey.PLAFOND_SOUS_CATEGORIES_NON_ABONNE: 3,
    SettingKey.PLAFOND_PUBLICATIONS_NON_ABONNE: 5,
    SettingKey.LIMITE_APPELS_PAR_MINUTE: 5,
    SettingKey.LIMITE_APPELS_PAR_JOUR: 50,
    SettingKey.SEUIL_APPELS_ABONNEMENT: 10,
}

# Pour ces cinq réglages, 0 n'a pas de sens (aucun appel possible, proposition
# d'abonnement permanente, aucune sous-catégorie ou publication) : minimum 1.
MIN_VALUE = 1


class UnknownSettingError(LookupError):
    """Clé de réglage absente de `SettingKey`."""

    def __init__(self, key):
        self.key = key
        super().__init__(
            f"Réglage de plateforme inconnu : « {key} ». "
            f"Clés possibles : {', '.join(SettingKey.values)}."
        )


class PlatformSetting(TimeStampedModel):
    key = models.CharField(
        "clé",
        max_length=64,
        unique=True,
        choices=SettingKey.choices,
    )
    value = models.PositiveIntegerField("valeur", validators=[MinValueValidator(MIN_VALUE)])
    modified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="modifié par",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="+",
    )

    class Meta:
        verbose_name = "réglage de plateforme"
        verbose_name_plural = "réglages de plateforme"
        ordering = ("key",)

    def __str__(self) -> str:
        return f"{self.key} = {self.value}"

    def clean_fields(self, exclude=None):
        # Clé inconnue : un message clair qui nomme la clé, à la place du message
        # générique « n'est pas un choix valide ».
        if self.key not in SettingKey.values and not (exclude and "key" in exclude):
            raise ValidationError(
                {"key": [str(UnknownSettingError(self.key))]}, code="unknown_setting"
            )
        # IntegerField tronquerait 2.5 en 2 sans rien dire : on refuse toute valeur non entière.
        if isinstance(self.value, bool) or (
            isinstance(self.value, float | Decimal) and self.value != int(self.value)
        ):
            raise ValidationError(
                {"value": ["La valeur doit être un nombre entier."]}, code="invalid"
            )
        super().clean_fields(exclude=exclude)

    def save(self, *args, **kwargs):
        # Validation à chaque écriture, pas seulement depuis un formulaire.
        self.full_clean(validate_unique=False)
        super().save(*args, **kwargs)
