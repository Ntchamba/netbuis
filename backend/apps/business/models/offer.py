"""Offer : ce que le commerçant propose (T037) — produit ou service, avec son prix.

- `price_fcfa` : entier ≥ 0 en FCFA ; vide (`None`) = « sur demande ».
- `photos` : liste de clés de stockage (kind `photo`, voir `storage_service`), 4 au plus.
- `catalog_product` : lien facultatif vers un produit du catalogue de recherche.
- Aucun compteur sur l'offre : vues et appels sont sur le profil (`BusinessProfile`).
"""
from django.core.exceptions import ValidationError
from django.db import models

from apps.core.models.base import TimeStampedModel

MAX_PHOTOS = 4


class Offer(TimeStampedModel):
    profile = models.ForeignKey(
        "business.BusinessProfile", verbose_name="compte business",
        on_delete=models.CASCADE, related_name="offers",
    )
    name = models.CharField("nom", max_length=150)
    description = models.TextField("description", blank=True, default="", max_length=1000)
    price_fcfa = models.PositiveIntegerField(
        "prix (FCFA)", null=True, blank=True, help_text="Vide = sur demande."
    )
    photos = models.JSONField("photos", default=list, blank=True)
    catalog_product = models.ForeignKey(
        "catalog.CatalogProduct", verbose_name="produit du catalogue", null=True, blank=True,
        on_delete=models.SET_NULL, related_name="offers",
    )
    is_active = models.BooleanField("actif", default=True)

    class Meta:
        verbose_name = "offre"
        verbose_name_plural = "offres"
        ordering = ["-created_at", "-id"]
        indexes = [models.Index(fields=["profile", "is_active"], name="business_offer_profile_act")]

    def __str__(self) -> str:
        return self.name

    @property
    def on_request(self) -> bool:
        return self.price_fcfa is None

    def clean(self):
        errors = {}
        if not (self.name or "").strip():
            errors["name"] = "Le nom est obligatoire."
        if not isinstance(self.photos, list) or not all(isinstance(p, str) for p in self.photos):
            errors["photos"] = "Liste de photos invalide."
        elif len(self.photos) > MAX_PHOTOS:
            errors["photos"] = f"{MAX_PHOTOS} photos au maximum."
        if errors:
            raise ValidationError(errors)

    def save(self, *args, **kwargs):
        self.clean()
        super().save(*args, **kwargs)
