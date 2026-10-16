"""Permissions des routes de l'API (T008).

- IsAuthenticatedNotBlocked : permission par défaut de DRF (config/settings/base.py).
  Un jeton d'accès encore valable (≤ 15 min) est refusé dès que le compte est bloqué
  ou supprimé : user.can_login() est revérifié à chaque requête.
- IsActiveBusinessOwner : en plus, le compte possède un BusinessProfile au statut
  « actif » (docs/spec/MODELE_DONNEES.md).
- IsAdminRole : PROVISOIRE (User.is_admin) ; la version définitive avec les groupes
  « Validateur » / « Administrateur complet » est faite en T070.
"""
from rest_framework.permissions import BasePermission

BUSINESS_STATUS_ACTIVE = "actif"  # docs/spec/MODELE_DONNEES.md, BusinessProfile.status


class IsAuthenticatedNotBlocked(BasePermission):
    """Connecté avec un compte qui passe user.can_login().

    Compte bloqué ou supprimé : 403 account_blocked / account_deleted
    (« Contactez le support ») ; compte inactif : 401 token_invalid.
    """

    def has_permission(self, request, view):
        user = request.user
        if not (user and user.is_authenticated):
            return False
        # Import à l'appel : ce module est chargé par DRF (DEFAULT_PERMISSION_CLASSES)
        # pendant l'import de rest_framework.views, que token_service importe aussi.
        from apps.accounts.services.token_service import check_can_login

        check_can_login(user)
        return True


class IsActiveBusinessOwner(IsAuthenticatedNotBlocked):
    def has_permission(self, request, view):
        if not super().has_permission(request, view):
            return False
        profile = request.user.business_profile_or_none
        return profile is not None and profile.status == BUSINESS_STATUS_ACTIVE


class IsAdminRole(IsAuthenticatedNotBlocked):
    """Provisoire : administrateur = User.is_admin (groupes en T070)."""

    def has_permission(self, request, view):
        return super().has_permission(request, view) and bool(request.user.is_admin)
