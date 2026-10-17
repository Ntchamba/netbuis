"""Produit du catalogue de recherche (T021) : sert à la complétion quand un commerçant tape
le nom d'un produit. Ce n'est pas l'offre d'un commerçant (cela viendra avec `business`).

`category` : une sous-catégorie facultative (le secteur s'en déduit).
"""
from django.contrib.postgres.indexes import GinIndex
from django.core.exceptions import ValidationError
from django.db import models

from apps.core.models.base import TimeStampedModel
from apps.core.utils.text_normalize import normalize_text


class CatalogProduct(TimeStampedModel):
    name = models.CharField("nom", max_length=150)
    normalized_name = models.CharField(
        "nom normalisé", max_length=150, editable=False,
        help_text="Minuscules, sans accents (calculé à l'enregistrement).",
    )
    category = models.ForeignKey(
        "catalog.Subcategory", verbose_name="catégorie (sous-catégorie)", null=True, blank=True,
        on_delete=models.SET_NULL, related_name="products",
    )
    is_active = models.BooleanField("actif", default=True)

    class Meta:
        verbose_name = "produit du catalogue"
        verbose_name_plural = "produits du catalogue"
        ordering = ["normalized_name", "id"]
        constraints = [
            models.UniqueConstraint(fields=["normalized_name"], name="catalog_product_unique_name")
        ]
        indexes = [
            GinIndex(
                fields=["normalized_name"], opclasses=["gin_trgm_ops"],
                name="catalog_product_name_trgm",
            )
        ]

    def __str__(self) -> str:
        return self.name

    def clean(self):
        self.normalized_name = normalize_text(self.name)
        if not self.normalized_name:
            raise ValidationError({"name": "Le nom est obligatoire."})
        others = CatalogProduct.objects.filter(normalized_name=self.normalized_name)
        if self.pk is not None:
            others = others.exclude(pk=self.pk)
        if others.exists():
            raise ValidationError({"name": "Un produit de ce nom existe déjà dans le catalogue."})

    def save(self, *args, **kwargs):
        self.clean()
        update_fields = kwargs.get("update_fields")
        if update_fields is not None and "name" in update_fields:
            kwargs["update_fields"] = {*update_fields, "normalized_name"}
        super().save(*args, **kwargs)
