"""Permissions communes.

Les permissions liées au compte (IsAuthenticatedNotBlocked, IsActiveBusinessOwner,
IsAdminRole) sont dans apps/accounts/permissions.py (T008).
"""
from rest_framework.permissions import BasePermission


class IsOwner(BasePermission):
    """L'objet appartient à l'utilisateur (attribut `owner` ou `user`)."""

    def has_object_permission(self, request, view, obj):
        owner = getattr(obj, "owner", None) or getattr(obj, "user", None)
        return owner is not None and owner == request.user
