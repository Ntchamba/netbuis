"""État d'un compte : blocage et suppression douce (T072, zone sensible).

Seul endroit (avec DELETE /api/me/) qui écrit `is_blocked`, `blocked_reason`, `blocked_at`,
`is_deleted`, `deleted_at`. Chaque changement invalide les jetons de rafraîchissement du
compte ; les jetons d'accès restants (≤ 15 min) sont refusés par user.can_login().

À appeler dans une transaction, sur un compte verrouillé (`select_for_update`) : l'audit et
les contrôles de droits sont à la charge de l'appelant (apps.admin_panel).
"""
from django.utils import timezone

from apps.accounts.services.token_service import revoke_all_refresh


def block(user, reason: str) -> None:
    user.is_blocked = True
    user.blocked_reason = reason
    user.blocked_at = timezone.now()
    user.save(update_fields=["is_blocked", "blocked_reason", "blocked_at", "updated_at"])
    revoke_all_refresh(user)


def unblock(user) -> None:
    user.is_blocked = False
    user.blocked_reason = ""
    user.blocked_at = None
    user.save(update_fields=["is_blocked", "blocked_reason", "blocked_at", "updated_at"])


def soft_delete(user) -> None:
    user.is_deleted = True
    user.deleted_at = timezone.now()
    user.save(update_fields=["is_deleted", "deleted_at", "updated_at"])
    revoke_all_refresh(user)


def restore(user) -> None:
    user.is_deleted = False
    user.deleted_at = None
    user.save(update_fields=["is_deleted", "deleted_at", "updated_at"])
