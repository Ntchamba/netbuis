"""Décision sur une demande de compte business (T071, zone sensible).

Statut et audit sont écrits dans UNE transaction : si l'audit échoue, rien n'est changé.
"""
from django.db import transaction

from apps.admin_panel.models import AuditAction
from apps.admin_panel.services import audit_service
from apps.business.models import BusinessProfile, BusinessStatus
from apps.business.services import verification_service


def pending_queryset():
    """Profils en attente dont le compte n'est pas supprimé, du plus ancien au plus récent."""
    return (
        BusinessProfile.objects.filter(
            status=BusinessStatus.PENDING, owner__is_deleted=False
        )
        .select_related("owner", "zone", "categorie_service")
        .order_by("created_at", "id")
    )


def decidable_queryset():
    return BusinessProfile.objects.filter(owner__is_deleted=False)


@transaction.atomic
def approve(admin, profile: BusinessProfile) -> BusinessProfile:
    verification_service.approve(profile)
    audit_service.record_action(admin, AuditAction.VALIDATION_BUSINESS, profile)
    return profile


@transaction.atomic
def reject(admin, profile: BusinessProfile, reason: str) -> BusinessProfile:
    reason = (reason or "").strip()
    if not reason:  # avant tout changement : un rejet sans motif ne touche à rien
        raise audit_service.ReasonRequired()
    if len(reason) > audit_service.MAX_REASON:
        raise audit_service.ReasonRequired(
            f"Le motif est trop long ({audit_service.MAX_REASON} caractères au plus)."
        )
    verification_service.reject(profile, reason)
    audit_service.record_action(admin, AuditAction.REJET_BUSINESS, profile, reason)
    return profile
