"""Référentiels publics : secteurs, sous-catégories, catégories de service, types de structure
(T021, docs/spec/MODELE_DONNEES.md). Tout est modifiable depuis l'admin Django : rien n'est figé
dans le code, `seed_referentials` ne fait que fournir le jeu de départ.

Chaque ligne a un `code` stable (minuscules, chiffres, « _ ») que le mobile peut utiliser ;
le nom, l'icône, l'ordre et l'activation se changent librement.
"""
from django.core.validators import RegexValidator
from django.db import models

from apps.core.models.base import TimeStampedModel

code_validator = RegexValidator(
    r"^[a-z0-9]+(?:_[a-z0-9]+)*$",
    "Le code stable ne contient que des minuscules sans accents, des chiffres et des tirets "
    "bas (ex. boutique_superette).",
)


class ReferentialItem(TimeStampedModel):
    """Champs communs à toutes les lignes de référentiel."""

    name = models.CharField("nom", max_length=100)
    icon = models.CharField("icône", max_length=16, blank=True, default="")
    order = models.PositiveIntegerField("ordre", default=0)
    is_active = models.BooleanField("actif", default=True)

    class Meta:
        abstract = True
        ordering = ["order", "name", "id"]

    def __str__(self) -> str:
        return f"{self.icon} {self.name}".strip()


class Sector(ReferentialItem):
    """Secteur d'activité (« Secteur » de la spec) : 10 valeurs au départ."""

    code = models.CharField(
        "code stable", max_length=50, unique=True, validators=[code_validator],
        help_text="Minuscules sans accents (ex. alimentation). Ne pas le changer une fois publié.",
    )

    class Meta(ReferentialItem.Meta):
        verbose_name = "secteur"
        verbose_name_plural = "secteurs"


class Subcategory(ReferentialItem):
    """Sous-catégorie d'un secteur (« SousCategorie » de la spec)."""

    sector = models.ForeignKey(
        Sector, verbose_name="secteur", on_delete=models.CASCADE, related_name="subcategories"
    )
    code = models.CharField(
        "code stable", max_length=60, validators=[code_validator],
        help_text="Unique dans le secteur (ex. fruits).",
    )

    class Meta(ReferentialItem.Meta):
        verbose_name = "sous-catégorie"
        verbose_name_plural = "sous-catégories"
        ordering = ["sector__order", "order", "name", "id"]
        constraints = [
            models.UniqueConstraint(
                fields=["sector", "code"], name="catalog_subcategory_unique_code"
            )
        ]

    def __str__(self) -> str:
        return f"{self.sector.name} › {self.name}"


class ServiceCategory(ReferentialItem):
    """Catégorie de service d'un prestataire (« CategorieService » de la spec) : 7 valeurs."""

    code = models.CharField(
        "code stable", max_length=50, unique=True, validators=[code_validator],
        help_text="Minuscules sans accents (ex. evenementiel).",
    )

    class Meta(ReferentialItem.Meta):
        verbose_name = "catégorie de service"
        verbose_name_plural = "catégories de service"


class StructureType(ReferentialItem):
    """Type de structure (« TypeStructure » de la spec) : 5 valeurs."""

    code = models.CharField(
        "code stable", max_length=50, unique=True, validators=[code_validator],
        help_text="Minuscules sans accents (ex. centre_sante).",
    )

    class Meta(ReferentialItem.Meta):
        verbose_name = "type de structure"
        verbose_name_plural = "types de structure"
