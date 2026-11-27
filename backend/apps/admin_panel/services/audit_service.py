"""Service UNIQUE qui écrit le journal d'audit (T070, zone sensible).

Toute action d'administration passe par `record_action`. Un rejet, un blocage ou une
suppression sans motif (vide ou espaces) est refusé : rien n'est écrit, 400 `reason_required`.
"""
from django.db import models
from rest_framework import status

from apps.core.exceptions import ApiError

from ..models import ACTIONS_AVEC_MOTIF, AuditAction, AuditLog

MAX_REASON = 1000


class ReasonRequired(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "reason_required"
    default_detail = "Un motif est obligatoire pour cette action."


class InvalidAuditEntry(ValueError):
    """Erreur de programmation : action inconnue, auteur non admin ou cible invalide."""


def record_action(admin, action: str, target: models.Model, reason: str = "") -> AuditLog:
    try:
        action = AuditAction(action)
    except ValueError as exc:
        raise InvalidAuditEntry(f"Action d'audit inconnue : {action!r}") from exc
    if admin is None or not getattr(admin, "is_admin", False):
        raise InvalidAuditEntry("L'auteur d'une action d'audit doit être un administrateur.")
    if not isinstance(target, models.Model) or target.pk is None:
        raise InvalidAuditEntry("La cible d'une action d'audit doit être un objet enregistré.")
    reason = (reason or "").strip()
    if action in ACTIONS_AVEC_MOTIF and not reason:
        raise ReasonRequired()
    if len(reason) > MAX_REASON:
        raise ReasonRequired(f"Le motif est trop long ({MAX_REASON} caractères au plus).")
    return AuditLog.objects.create(
        admin=admin,
        action=action,
        target_type=target._meta.label_lower,
        target_id=target.pk,
        reason=reason,
    )
