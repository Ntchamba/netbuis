"""Comptes (T072, zone sensible).

- GET    /api/admin/accounts/            liste filtrable (peut_voir_comptes), numéro masqué
- GET    /api/admin/accounts/<id>/       vue détaillée ; numéro complet : Administrateur complet
- POST   /api/admin/accounts/<id>/block/ | unblock/   (peut_bloquer_compte, motif pour block)
- DELETE /api/admin/accounts/<id>/       suppression douce (peut_supprimer_compte, motif)
- POST   /api/admin/accounts/<id>/restore/            (peut_supprimer_compte)
"""
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import generics
from rest_framework.exceptions import NotFound
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.serializers.otp import ErrorSerializer
from apps.admin_panel.permissions import require
from apps.admin_panel.serializers.account import (
    AccountDetailSerializer,
    AccountListSerializer,
    AccountReasonSerializer,
    AccountStateSerializer,
)
from apps.admin_panel.services import account_service, rights_service

_ERRORS = {
    401: OpenApiResponse(response=ErrorSerializer, description="Jeton absent ou invalide"),
    403: OpenApiResponse(
        response=ErrorSerializer,
        description="Pas administrateur, sans groupe, sans la permission, ou compte bloqué",
    ),
}
_NOT_FOUND = OpenApiResponse(response=ErrorSerializer, description="not_found")
_SELF = OpenApiResponse(
    response=ErrorSerializer,
    description="reason_required (motif manquant, rien n'est écrit) ou "
                "self_action_forbidden (action sur son propre compte)",
)
_STATE = OpenApiResponse(
    response=ErrorSerializer,
    description="invalid_state, ou last_full_admin (dernier Administrateur complet actif)",
)


class AccountListView(generics.ListAPIView):
    permission_classes = [require(rights_service.VOIR_COMPTES)]
    serializer_class = AccountListSerializer
    http_method_names = ["get", "options"]

    def get_queryset(self):
        params = self.request.query_params
        return account_service.list_queryset(
            kind=params.get("type", "all"), zone=params.get("zone"), query=params.get("q", ""),
            search_phone=account_service.can_see_full_phone(self.request.user),
        )

    @extend_schema(
        tags=["admin"], operation_id="admin_accounts_list",
        parameters=[
            OpenApiParameter("type", str, enum=list(account_service.TYPES),
                             description="all (défaut), simple, business, blocked, deleted"),
            OpenApiParameter("zone", int, description="Zone (ville, quartier…) : comptes "
                             "business situés dans cette zone ou celles qu'elle contient"),
            OpenApiParameter("q", str, description="Nom du compte ou du commerce, ou numéro "
                             "(chiffres, 3 au moins ; Administrateur complet seulement, "
                             "ignoré pour un Validateur) ; le numéro reste masqué dans la réponse"),
        ],
        description="Comptes, du plus récent au plus ancien, paginés. Numéro toujours masqué.",
        responses={200: AccountListSerializer(many=True),
                   400: OpenApiResponse(response=ErrorSerializer,
                                        description="invalid_type / invalid_zone"),
                   **_ERRORS},
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


class AccountDetailView(APIView):
    http_method_names = ["get", "delete", "options"]

    def get_permissions(self):
        code = (rights_service.SUPPRIMER_COMPTE if self.request.method == "DELETE"
                else rights_service.VOIR_COMPTES)
        return [require(code)()]

    @extend_schema(
        tags=["admin"], operation_id="admin_accounts_retrieve",
        description=(
            "Vue détaillée : identité, type, profil business et pièces (URL temporaires de "
            "5 min liées à l'administrateur), historique de statuts, dernières actions "
            "d'audit. `phone` (numéro complet) n'est renvoyé qu'à l'Administrateur complet "
            "et chaque affichage est audité (`consultation_numero`) ; sinon il vaut null."
        ),
        responses={200: AccountDetailSerializer, 404: _NOT_FOUND, **_ERRORS},
    )
    def get(self, request, pk):
        user = account_service.base_queryset().filter(pk=pk).first()
        if user is None:
            raise NotFound()
        context = {"request": request, "full_phone": account_service.full_phone_for(
            request.user, user)}
        response = Response(AccountDetailSerializer(user, context=context).data)
        response["Cache-Control"] = "no-store"
        return response

    @extend_schema(
        tags=["admin"], operation_id="admin_accounts_delete", request=AccountReasonSerializer,
        description=("Suppression DOUCE (`is_deleted`, `deleted_at`) avec motif obligatoire "
                     "dans le corps ; jetons de rafraîchissement invalidés. Audit "
                     "`suppression_compte`."),
        responses={200: AccountStateSerializer, 400: _SELF, 404: _NOT_FOUND, 409: _STATE,
                   **_ERRORS},
    )
    def delete(self, request, pk):
        reason = _reason(request)
        return Response(AccountStateSerializer(
            account_service.soft_delete(request.user, pk, reason)).data)


def _reason(request) -> str:
    serializer = AccountReasonSerializer(data=request.data if request.data else {})
    serializer.is_valid(raise_exception=True)
    return serializer.validated_data.get("reason", "")


class _ActionView(APIView):
    http_method_names = ["post", "options"]


class BlockView(_ActionView):
    permission_classes = [require(rights_service.BLOQUER_COMPTE)]

    @extend_schema(
        tags=["admin"], operation_id="admin_accounts_block", request=AccountReasonSerializer,
        description=("Bloque le compte (motif obligatoire, 255 caractères au plus) : plus de "
                     "connexion, jetons invalidés, disparu de la recherche, des fiches et des "
                     "appels. Audit `blocage_compte`."),
        responses={200: AccountStateSerializer, 400: _SELF, 404: _NOT_FOUND, 409: _STATE,
                   **_ERRORS},
    )
    def post(self, request, pk):
        user = account_service.block(request.user, pk, _reason(request))
        return Response(AccountStateSerializer(user).data)


class UnblockView(_ActionView):
    permission_classes = [require(rights_service.BLOQUER_COMPTE)]

    @extend_schema(
        tags=["admin"], operation_id="admin_accounts_unblock", request=None,
        description="Débloque le compte. Audit `deblocage_compte`.",
        responses={200: AccountStateSerializer, 400: _SELF, 404: _NOT_FOUND, 409: _STATE,
                   **_ERRORS},
    )
    def post(self, request, pk):
        return Response(AccountStateSerializer(account_service.unblock(request.user, pk)).data)


class RestoreView(_ActionView):
    permission_classes = [require(rights_service.SUPPRIMER_COMPTE)]

    @extend_schema(
        tags=["admin"], operation_id="admin_accounts_restore", request=None,
        description="Restaure un compte supprimé. Audit `restauration_compte`.",
        responses={200: AccountStateSerializer, 404: _NOT_FOUND, 409: _STATE, **_ERRORS},
    )
    def post(self, request, pk):
        return Response(AccountStateSerializer(account_service.restore(request.user, pk)).data)
