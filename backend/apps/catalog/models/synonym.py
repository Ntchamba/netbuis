"""Synonyme d'un produit du catalogue (T021) : un mot que les gens tapent à la place du nom
officiel. Le terme est comparé sans accents ni majuscules (`normalized_term`)."""
from django.contrib.postgres.indexes import GinIndex
from django.core.exceptions import ValidationError
from django.db import models

from apps.core.models.base import TimeStampedModel
from apps.core.utils.text_normalize import normalize_text


class Synonym(TimeStampedModel):
    product = models.ForeignKey(
        "catalog.CatalogProduct", verbose_name="produit", on_delete=models.CASCADE,
        related_name="synonyms",
    )
    term = models.CharField("synonyme", max_length=150)
    normalized_term = models.CharField(
        "terme normalisé", max_length=150, editable=False,
        help_text="Minuscules, sans accents (calculé à l'enregistrement).",
    )

    class Meta:
        verbose_name = "synonyme"
        verbose_name_plural = "synonymes"
        ordering = ["normalized_term", "id"]
        constraints = [
            models.UniqueConstraint(
                fields=["product", "normalized_term"], name="catalog_synonym_unique_term"
            )
        ]
        indexes = [
            GinIndex(
                fields=["normalized_term"], opclasses=["gin_trgm_ops"],
                name="catalog_synonym_term_trgm",
            )
        ]

    def __str__(self) -> str:
        return self.term

    def clean(self):
        self.normalized_term = normalize_text(self.term)
        if not self.normalized_term:
            raise ValidationError({"term": "Le synonyme est obligatoire."})
        if self.product_id is not None:
            others = Synonym.objects.filter(
                product_id=self.product_id, normalized_term=self.normalized_term
            )
            if self.pk is not None:
                others = others.exclude(pk=self.pk)
            if others.exists():
                raise ValidationError({"term": "Ce synonyme existe déjà pour ce produit."})

    def save(self, *args, **kwargs):
        self.clean()
        update_fields = kwargs.get("update_fields")
        if update_fields is not None and "term" in update_fields:
            kwargs["update_fields"] = {*update_fields, "normalized_term"}
        super().save(*args, **kwargs)
