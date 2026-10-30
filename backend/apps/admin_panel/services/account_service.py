"""Comptes vus par l'administration (T072, zone sensible : revue ligne par ligne).

- Liste filtrable (type, zone, recherche) ; le numéro n'y est jamais en clair.
- Blocage / déblocage / suppression douce / restauration : le compte est verrouillé, l'état
  et l'audit s'écrivent dans UNE transaction (un échec d'audit annule le changement).
- Un administrateur ne peut agir ni sur lui-même (400 `self_action_forbidden`).
- Le numéro complet n'est lu que par `full_phone_for`, qui écrit l'audit `consultation_numero`.
"""
import re

from django.db import models, transaction
from rest_framework import status
from rest_framework.exceptions import NotFound

from apps.accounts.models import User
from apps.accounts.services import account_state_service
from apps.admin_panel.models import AuditAction, AuditLog
from apps.admin_panel.services import audit_service, rights_service
from apps.core.exceptions import ApiError
from apps.geo.models import Zone
from apps.search.services.filters import zone_parents, zone_subtree_ids

TYPES = ("all", "simple", "business", "blocked", "deleted")
MAX_BLOCK_REASON = 255  # taille de User.blocked_reason
STATUS_ACTIONS = (
    AuditAction.BLOCAGE_COMPTE, AuditAction.DEBLOCAGE_COMPTE, AuditAction.SUPPRESSION_COMPTE,
    AuditAction.RESTAURATION_COMPTE, AuditAction.VALIDATION_BUSINESS, AuditAction.REJET_BUSINESS,
)
USER_LABEL = User._meta.label_lower
PROFILE_LABEL = "business.businessprofile"


class InvalidAccountType(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "invalid_type"
    default_detail = "Filtre inconnu. Valeurs : all, simple, business, blocked, deleted."


class InvalidZone(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "invalid_zone"
    default_detail = "Zone inconnue."


class SelfActionForbidden(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "self_action_forbidden"
    default_detail = "Vous ne pouvez pas bloquer ni supprimer votre propre compte."


class LastFullAdmin(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "last_full_admin"
    default_detail = "C'est le dernier Administrateur complet actif : action refusée."


class InvalidState(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "invalid_state"
    default_detail = "Cette action n'est pas possible dans l'état actuel du compte."


def account_status(user) -> str:
    if user.is_deleted:
        return "supprime"
    if user.is_blocked:
        return "bloque"
    return "actif"


# --- Liste ---------------------------------------------------------------------------


def base_queryset():
    return User.objects.select_related("business_profile__zone").order_by("-created_at", "-id")


def list_queryset(*, kind="all", zone=None, query="", search_phone=False):
    if kind not in TYPES:
        raise InvalidAccountType()
    qs = base_queryset()
    if kind == "simple":
        qs = qs.filter(business_profile__isnull=True)
    elif kind == "business":
        qs = qs.filter(business_profile__isnull=False)
    elif kind == "blocked":
        qs = qs.filter(is_blocked=True)
    elif kind == "deleted":
        qs = qs.filter(is_deleted=True)
    if zone not in (None, ""):
        try:
            zone_obj = Zone.objects.filter(pk=int(zone)).first()
        except (TypeError, ValueError):
            zone_obj = None
        if zone_obj is None:
            raise InvalidZone()
        ids = zone_subtree_ids(zone_obj, zone_parents())
        qs = qs.filter(business_profile__zone_id__in=ids)
    query = (query or "").strip()
    if query:
        cond = models.Q(name__icontains=query) | models.Q(business_profile__name__icontains=query)
        digits = re.sub(r"\D", "", query)
        # Recherche par numéro : Administrateur complet seulement (sinon un Validateur
        # reconstituerait un numéro chiffre par chiffre) ; pour lui, la partie numéro est ignorée.
        if search_phone and len(digits) >= 3 and re.fullmatch(r"[\d\s+.\-()]+", query):
            cond |= models.Q(phone__contains=digits)
        qs = qs.filter(cond)
    return qs


# --- Actions ---------------------------------------------------------------------------


def _locked(admin, pk, *, allow_self=False) -> User:
    user = User.objects.select_for_update().filter(pk=pk).first()
    if user is None:
        raise NotFound()
    if not allow_self and user.pk == admin.pk:
        raise SelfActionForbidden()
    return user


def _guard_last_full_admin(user) -> None:
    """Refuse de bloquer/supprimer le dernier Administrateur complet actif."""
    if rights_service.GROUP_ADMIN_COMPLET not in rights_service.admin_roles(user):
        return
    others = User.objects.filter(
        is_admin=True, is_active=True, is_blocked=False, is_deleted=False,
        groups__name=rights_service.GROUP_ADMIN_COMPLET,
    ).exclude(pk=user.pk)
    if not others.exists():
        raise LastFullAdmin()


def _clean_reason(reason: str, limit: int) -> str:
    reason = (reason or "").strip()
    if not reason:
        raise audit_service.ReasonRequired()
    if len(reason) > limit:
        raise audit_service.ReasonRequired(f"Le motif est trop long ({limit} caractères au plus).")
    return reason


@transaction.atomic
def block(admin, pk, reason) -> User:
    user = _locked(admin, pk)
    reason = _clean_reason(reason, MAX_BLOCK_REASON)
    if user.is_deleted or user.is_blocked:
        raise InvalidState("Ce compte est déjà bloqué ou supprimé.")
    _guard_last_full_admin(user)
    account_state_service.block(user, reason)
    audit_service.record_action(admin, AuditAction.BLOCAGE_COMPTE, user, reason)
    return user


@transaction.atomic
def unblock(admin, pk) -> User:
    user = _locked(admin, pk)
    if not user.is_blocked:
        raise InvalidState("Ce compte n'est pas bloqué.")
    account_state_service.unblock(user)
    audit_service.record_action(admin, AuditAction.DEBLOCAGE_COMPTE, user)
    return user


@transaction.atomic
def soft_delete(admin, pk, reason) -> User:
    user = _locked(admin, pk)
    reason = _clean_reason(reason, audit_service.MAX_REASON)
    if user.is_deleted:
        raise InvalidState("Ce compte est déjà supprimé.")
    _guard_last_full_admin(user)
    account_state_service.soft_delete(user)
    audit_service.record_action(admin, AuditAction.SUPPRESSION_COMPTE, user, reason)
    return user


@transaction.atomic
def restore(admin, pk) -> User:
    user = _locked(admin, pk, allow_self=True)
    if not user.is_deleted:
        raise InvalidState("Ce compte n'est pas supprimé.")
    account_state_service.restore(user)
    audit_service.record_action(admin, AuditAction.RESTAURATION_COMPTE, user)
    return user


# --- Vue détaillée ---------------------------------------------------------------------


def can_see_full_phone(admin) -> bool:
    """Administrateur complet seulement (le Validateur voit le numéro masqué)."""
    return rights_service.GROUP_ADMIN_COMPLET in rights_service.admin_roles(admin)


def full_phone_for(admin, user) -> str | None:
    """Numéro complet si `admin` y a droit ; chaque affichage est audité (même transaction)."""
    if not can_see_full_phone(admin):
        return None
    with transaction.atomic():
        audit_service.record_action(admin, AuditAction.CONSULTATION_NUMERO, user)
    return user.phone


def status_history(user, limit=20):
    """Changements de statut du compte et de son dossier business, du plus récent au plus ancien."""
    cond = models.Q(target_type=USER_LABEL, target_id=user.pk)
    profile = user.business_profile_or_none
    if profile is not None:
        cond |= models.Q(target_type=PROFILE_LABEL, target_id=profile.pk)
    return list(
        AuditLog.objects.filter(cond, action__in=STATUS_ACTIONS)
        .select_related("admin")[:limit]
    )


def recent_audit(user, limit=10):
    """Dernières actions d'audit visant ce compte."""
    return list(
        AuditLog.objects.filter(target_type=USER_LABEL, target_id=user.pk)
        .select_related("admin")[:limit]
    )
