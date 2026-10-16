"""Permissions communes. « Administrateur » = User.is_admin (provisoire, groupes en T070)."""
from rest_framework.permissions import BasePermission


class IsAdminRole(BasePermission):
    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and getattr(user, "is_admin", False))


class IsOwner(BasePermission):
    """L'objet appartient à l'utilisateur (attribut `owner` ou `user`)."""

    def has_object_permission(self, request, view, obj):
        owner = getattr(obj, "owner", None) or getattr(obj, "user", None)
        return owner is not None and owner == request.user
