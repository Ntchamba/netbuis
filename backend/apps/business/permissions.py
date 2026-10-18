"""Permissions de l'espace commerçant (T026).

IsMerchantOwner : compte connecté non bloqué (héritage) ET, pour un objet, propriétaire de ce
compte business. L'existence du profil n'est pas exigée au niveau de la route : un compte sans
profil reçoit 404 `no_business` de la vue, pas un 403.
"""
from apps.accounts.permissions import IsAuthenticatedNotBlocked


class IsMerchantOwner(IsAuthenticatedNotBlocked):
    def has_object_permission(self, request, view, obj):
        return obj.owner_id == request.user.pk
