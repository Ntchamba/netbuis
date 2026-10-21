"""AuditLog : qui a fait quoi, sur qui, pourquoi, quand (T070).

Écrit uniquement par `services.audit_service.record_action`. Aucun numéro de téléphone
ni secret n'est stocké : la cible est désignée par son type et son identifiant.
Ce modèle porte aussi les permissions `peut_…` de l'administration (groupes).
"""
from django.conf import settings
from django.db import models

from apps.admin_panel.services import rights_service as rights


class AuditAction(models.TextChoices):
    VALIDATION_BUSINESS = "validation_business", "Validation d'un compte business"
    REJET_BUSINESS = "rejet_business", "Rejet d'un compte business"
    BLOCAGE_COMPTE = "blocage_compte", "Blocage d'un compte"
    DEBLOCAGE_COMPTE = "deblocage_compte", "Déblocage d'un compte"
    SUPPRESSION_COMPTE = "suppression_compte", "Suppression d'un compte"
    RESTAURATION_COMPTE = "restauration_compte", "Restauration d'un compte"
    ATTRIBUTION_ROLE = "attribution_role", "Attribution d'un rôle"
    RETRAIT_ROLE = "retrait_role", "Retrait d'un rôle"
    MODIFICATION_REGLAGE = "modification_reglage", "Modification d'un réglage"
    ACCORD_ABONNEMENT = "accord_abonnement", "Accord d'un abonnement"
    MODERATION_CONTENU = "moderation_contenu", "Modération d'un contenu"


# Un motif est OBLIGATOIRE pour ces actions (spec : rejet, blocage, suppression).
ACTIONS_AVEC_MOTIF = frozenset(
    {AuditAction.REJET_BUSINESS, AuditAction.BLOCAGE_COMPTE, AuditAction.SUPPRESSION_COMPTE}
)


class AuditLog(models.Model):
    admin = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="audit_logs"
    )
    action = models.CharField(max_length=40, choices=AuditAction.choices, db_index=True)
    target_type = models.CharField("type de cible", max_length=60)
    target_id = models.PositiveBigIntegerField("identifiant de la cible")
    reason = models.TextField("motif", blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["-created_at", "-id"]
        default_permissions = ()
        permissions = [(code, label) for code, label in rights.PERMISSION_LABELS.items()]
        indexes = [models.Index(fields=["target_type", "target_id"])]

    def __str__(self):
        return f"{self.action} {self.target_type}#{self.target_id}"
