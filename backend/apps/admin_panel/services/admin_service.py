"""Administrateurs du dashboard (T074, zone sensible : revue ligne par ligne).

- Création : jamais d'auto-inscription ; seul un Administrateur complet (`peut_gerer_admins`)
  crée un compte Validateur ou Administrateur complet. Mode de première connexion : MOT DE
  PASSE TEMPORAIRE généré côté serveur (`secrets`), renvoyé UNE SEULE FOIS dans la réponse de
  création, jamais stocké en clair, jamais journalisé, jamais relisible ensuite.
- Un compte déjà existant (client, commerçant) n'est PAS promu : 409 `phone_exists`.
- Changement de rôle et retrait : audités (`attribution_role`, `retrait_role` + motif).
  Un administrateur ne peut pas modifier son propre rôle ; le dernier Administrateur complet
  actif ne peut être ni rétrogradé ni retiré.
"""
import secrets
import string

from django.contrib.auth.models import Group
from django.db import IntegrityError, transaction
from rest_framework import status
from rest_framework.exceptions import NotFound

from apps.accounts.models import User
from apps.accounts.services.token_service import revoke_all_refresh
from apps.admin_panel.models import AuditAction
from apps.admin_panel.services import audit_service, rights_service
from apps.admin_panel.services.account_service import LastFullAdmin
from apps.core.exceptions import ApiError
from apps.core.utils.phone import normalize_phone

ROLES = rights_service.ADMIN_GROUPS
TEMP_PASSWORD_LENGTH = 16
_ALPHABET = string.ascii_letters + string.digits


class InvalidPhone(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "invalid_phone"
    default_detail = "Numéro de téléphone camerounais invalide."


class InvalidRole(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "invalid_role"
    default_detail = "Rôle inconnu. Valeurs : Validateur, Administrateur complet."


class PhoneExists(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "phone_exists"
    default_detail = "Un compte existe déjà avec ce numéro."


class SelfRoleForbidden(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "self_action_forbidden"
    default_detail = "Vous ne pouvez pas modifier ni retirer votre propre rôle."


class NotAnAdmin(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "invalid_state"
    default_detail = "Ce compte n'a aucun rôle d'administration."


class SameRole(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "invalid_state"
    default_detail = "Ce compte a déjà ce rôle."


def generate_temporary_password() -> str:
    return "".join(secrets.choice(_ALPHABET) for _ in range(TEMP_PASSWORD_LENGTH))


def list_queryset():
    return (
        User.objects.filter(groups__name__in=ROLES)
        .distinct()
        .prefetch_related("groups")
        .order_by("-created_at", "-id")
    )


def roles_of(user) -> list[str]:
    """Rôles d'administration enregistrés (même si le compte est bloqué ou supprimé)."""
    names = {g.name for g in user.groups.all()}
    return [r for r in ROLES if r in names]


def _check_role(role) -> str:
    if role not in ROLES:
        raise InvalidRole()
    return role


def _locked_target(admin, pk) -> User:
    # Verrou sur les Administrateurs complets (garde du dernier) puis sur la cible.
    list(User.objects.select_for_update(of=("self",)).filter(
        groups__name=rights_service.GROUP_ADMIN_COMPLET).values_list("pk", flat=True))
    user = User.objects.select_for_update().filter(pk=pk).first()
    if user is None:
        raise NotFound()
    if user.pk == admin.pk:
        raise SelfRoleForbidden()
    return user


def _guard_last_full_admin(user) -> None:
    if rights_service.GROUP_ADMIN_COMPLET not in rights_service.admin_roles(user):
        return  # compte déjà inactif ou pas complet : il ne compte pas comme administrateur actif
    others = User.objects.filter(
        is_admin=True, is_active=True, is_blocked=False, is_deleted=False,
        groups__name=rights_service.GROUP_ADMIN_COMPLET,
    ).exclude(pk=user.pk)
    if not others.exists():
        raise LastFullAdmin()


def _set_role(user, role) -> None:
    user.groups.remove(*Group.objects.filter(name__in=ROLES))
    user.groups.add(Group.objects.get(name=role))


@transaction.atomic
def create_admin(admin, *, phone, name, role) -> tuple[User, str]:
    """Crée le compte ; renvoie (utilisateur, mot de passe temporaire à montrer une fois)."""
    _check_role(role)
    try:
        normalized = normalize_phone(phone)
    except ValueError as exc:
        raise InvalidPhone() from exc
    if User.objects.filter(phone=normalized).exists():
        raise PhoneExists()
    password = generate_temporary_password()
    try:
        with transaction.atomic():
            user = User.objects.create_user(normalized, password, name=name, is_admin=True)
    except IntegrityError as exc:
        raise PhoneExists() from exc
    _set_role(user, role)
    audit_service.record_action(admin, AuditAction.ATTRIBUTION_ROLE, user, f"rôle : {role}")
    return user, password


@transaction.atomic
def change_role(admin, pk, role) -> User:
    _check_role(role)
    user = _locked_target(admin, pk)
    current = roles_of(user)
    if not user.is_admin or not current:
        raise NotAnAdmin()
    if current == [role]:
        raise SameRole()
    if role != rights_service.GROUP_ADMIN_COMPLET:
        _guard_last_full_admin(user)
    _set_role(user, role)
    audit_service.record_action(
        admin, AuditAction.ATTRIBUTION_ROLE, user, f"rôle : {' + '.join(current)} -> {role}"
    )
    return user


@transaction.atomic
def remove_admin(admin, pk, reason) -> User:
    reason = (reason or "").strip()
    if not reason:
        raise audit_service.ReasonRequired()
    if len(reason) > audit_service.MAX_REASON:
        raise audit_service.ReasonRequired(
            f"Le motif est trop long ({audit_service.MAX_REASON} caractères au plus)."
        )
    user = _locked_target(admin, pk)
    current = roles_of(user)
    if not current:
        raise NotAnAdmin()
    _guard_last_full_admin(user)
    user.groups.remove(*Group.objects.filter(name__in=ROLES))
    user.is_admin = False
    user.save(update_fields=["is_admin", "updated_at"])
    revoke_all_refresh(user)
    audit_service.record_action(
        admin, AuditAction.RETRAIT_ROLE, user, f"{' + '.join(current)} : {reason}"
    )
    return user
