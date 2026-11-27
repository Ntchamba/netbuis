"""Instantané des tendances d'une ville pour une période (T104).

Un instantané par (ville, jour de fin de période) ; relancer le calcul le même jour le
REMPLACE. L'API ne lit que le plus récent : elle ne recalcule jamais à la requête.
Aucun compte, aucun numéro ici : seulement des produits du catalogue et des commerces.
"""
from django.db import models

from apps.core.models.base import TimeStampedModel


class TrendKind(models.TextChoices):
    PRODUCT = "product", "Produit"
    BUSINESS = "business", "Commerce"


class TrendSnapshot(TimeStampedModel):
    zone = models.ForeignKey(
        "geo.Zone", verbose_name="ville", on_delete=models.CASCADE, related_name="+"
    )
    period_end = models.DateField("fin de période")
    window_days = models.PositiveSmallIntegerField("durée (jours)")

    class Meta:
        verbose_name = "instantané de tendances"
        verbose_name_plural = "instantanés de tendances"
        ordering = ("-period_end", "zone_id")
        constraints = [
            models.UniqueConstraint(fields=["zone", "period_end"], name="trend_snapshot_unique"),
        ]

    def __str__(self) -> str:
        return f"Tendances {self.zone_id} au {self.period_end}"


class TrendEntry(models.Model):
    """Une ligne classée : un produit du catalogue OU un commerce (jamais les deux)."""

    snapshot = models.ForeignKey(
        TrendSnapshot, verbose_name="instantané", on_delete=models.CASCADE,
        related_name="entries",
    )
    kind = models.CharField("type", max_length=8, choices=TrendKind.choices)
    rank = models.PositiveSmallIntegerField("rang")
    product = models.ForeignKey(
        "catalog.CatalogProduct", verbose_name="produit", null=True, blank=True,
        on_delete=models.CASCADE, related_name="+",
    )
    profile = models.ForeignKey(
        "business.BusinessProfile", verbose_name="commerce", null=True, blank=True,
        on_delete=models.CASCADE, related_name="+",
    )
    hits = models.PositiveIntegerField("recherches ou contacts")
    accounts = models.PositiveIntegerField("comptes distincts")

    class Meta:
        verbose_name = "ligne de tendance"
        verbose_name_plural = "lignes de tendance"
        ordering = ("kind", "rank")
        constraints = [
            models.UniqueConstraint(fields=["snapshot", "kind", "rank"], name="trend_entry_rank"),
            models.CheckConstraint(
                condition=(
                    models.Q(kind="product", product__isnull=False, profile__isnull=True)
                    | models.Q(kind="business", profile__isnull=False, product__isnull=True)
                ),
                name="trend_entry_one_target",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.get_kind_display()} n°{self.rank}"
