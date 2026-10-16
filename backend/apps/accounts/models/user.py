"""User : téléphone E.164 unique, nom facultatif. Mot de passe réservé aux admins.

« Commerçant » = possède un BusinessProfile actif ; « administrateur » = is_admin.
is_staff reste réservé à l'accès à l'admin Django.
"""
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from django.db import models

from apps.core.models import TimeStampedModel

from .manager import UserManager


class User(AbstractBaseUser, PermissionsMixin, TimeStampedModel):
    phone = models.CharField("téléphone", max_length=16, unique=True)
    name = models.CharField("nom", max_length=120, blank=True)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    is_admin = models.BooleanField("administrateur NetBuis", default=False)
    is_blocked = models.BooleanField("bloqué", default=False)
    blocked_reason = models.CharField("motif du blocage", max_length=255, blank=True)
    blocked_at = models.DateTimeField("bloqué le", null=True, blank=True)
    is_deleted = models.BooleanField("supprimé", default=False)  # suppression douce (D-09)
    deleted_at = models.DateTimeField("supprimé le", null=True, blank=True)

    objects = UserManager()

    USERNAME_FIELD = "phone"
    REQUIRED_FIELDS: list[str] = []

    class Meta:
        verbose_name = "utilisateur"

    def __str__(self):
        return self.name or f"Utilisateur {self.pk}"

    def can_login(self) -> bool:
        """Seul point de contrôle d'accès : faux si inactif, bloqué ou supprimé."""
        return self.is_active and not self.is_blocked and not self.is_deleted
