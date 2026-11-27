"""Permissions des routes /api/admin/ (T070, zone sensible).

- IsDashboardAdmin : `IsAdminRole` (is_admin ET groupe), refus 403 sinon.
- require(code) : en plus, le groupe doit donner la permission `peut_…`.
Les droits sont relus en base à chaque requête.
"""
from apps.accounts.permissions import IsAdminRole as IsDashboardAdmin
from apps.admin_panel.services import rights_service


def require(codename: str):
    """Fabrique une classe de permission DRF exigeant la permission `codename`."""
    if codename not in rights_service.PERMISSION_LABELS:
        raise ValueError(f"Permission d'administration inconnue : {codename!r}")

    class _Require(IsDashboardAdmin):
        def has_permission(self, request, view):
            return super().has_permission(request, view) and rights_service.has_admin_permission(
                request.user, codename
            )

    _Require.__name__ = f"Require_{codename}"
    return _Require


__all__ = ["IsDashboardAdmin", "require"]
