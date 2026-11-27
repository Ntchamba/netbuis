"""Une vue de fiche par compte, par profil et par jour (T047b).

Sert uniquement à ne compter qu'une fois : la contrainte d'unicité rend l'enregistrement
atomique même si deux requêtes arrivent en même temps.
"""
from django.conf import settings
from django.db import models


class ProfileView(models.Model):
    profile = models.ForeignKey(
        "business.BusinessProfile", on_delete=models.CASCADE, related_name="view_records"
    )
    viewer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="+"
    )
    day = models.DateField("jour")

    class Meta:
        verbose_name = "vue de fiche"
        verbose_name_plural = "vues de fiche"
        constraints = [
            models.UniqueConstraint(
                fields=["profile", "viewer", "day"], name="business_profileview_once_a_day"
            )
        ]

    def __str__(self) -> str:
        return f"vue du profil {self.profile_id} le {self.day}"
