"""Changement de statut d'une demande de compte business (T071, zone sensible).

Seul endroit qui passe un profil de `en_attente_validation` à `actif` ou `rejete`.
N'écrit que `status`, `cni_verifiee`, `motif_rejet` (et la date de mise à jour). Le changement
est conditionnel (`WHERE status = en_attente_validation`) : deux validations simultanées ne
passent pas toutes les deux, la seconde reçoit `AlreadyProcessed` (409).
L'audit est écrit par l'appelant (apps.admin_panel), dans la même transaction.
"""
from django.db import transaction
from django.utils import timezone
from rest_framework import status

from apps.business.models import AccountType, BusinessProfile, BusinessStatus
from apps.core.exceptions import ApiError


class AlreadyProcessed(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "already_processed"
    default_detail = "Cette demande a déjà été traitée."


def _set_status(profile: BusinessProfile, **values) -> None:
    changed = BusinessProfile.objects.filter(
        pk=profile.pk, status=BusinessStatus.PENDING
    ).update(updated_at=timezone.now(), **values)
    if not changed:
        raise AlreadyProcessed()
    profile.refresh_from_db()


@transaction.atomic
def approve(profile: BusinessProfile) -> BusinessProfile:
    """`actif` ; pour un prestataire, la CNI est marquée vérifiée du même geste."""
    _set_status(
        profile,
        status=BusinessStatus.ACTIVE,
        motif_rejet="",
        cni_verifiee=profile.type_compte == AccountType.PRESTATAIRE_SERVICE,
    )
    return profile


@transaction.atomic
def reject(profile: BusinessProfile, reason: str) -> BusinessProfile:
    """`rejete` avec le motif (déjà contrôlé non vide par l'appelant)."""
    _set_status(
        profile, status=BusinessStatus.REJECTED, motif_rejet=reason, cni_verifiee=False
    )
    return profile
