"""Administrateurs (T074, zone sensible : Administrateur complet, `peut_gerer_admins`).

- GET    /api/admin/admins/            liste, numéros masqués
- POST   /api/admin/admins/            crée un Validateur / Administrateur complet
- PATCH  /api/admin/admins/<id>/       change le rôle (audit attribution_role)
- DELETE /api/admin/admins/<id>/       retire tout rôle, motif obligatoire (audit retrait_role)
"""
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework import generics
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.serializers.otp import ErrorSerializer
from apps.admin_panel.permissions import require
from apps.admin_panel.serializers.admin import (
    AdminCreatedSerializer,
    AdminCreateSerializer,
    AdminRemoveSerializer,
    AdminRoleSerializer,
    AdminSerializer,
)
from apps.admin_panel.services import admin_service, rights_service

_ERRORS = {
    401: OpenApiResponse(response=ErrorSerializer, description="Jeton absent ou invalide"),
    403: OpenApiResponse(
        response=ErrorSerializer,
        description="Pas administrateur, sans groupe, ou sans peut_gerer_admins",
    ),
}
_NOT_FOUND = OpenApiResponse(response=ErrorSerializer, description="not_found")
_BAD = OpenApiResponse(
    response=ErrorSerializer,
    description="invalid_phone / invalid_role / reason_required / self_action_forbidden",
)
_STATE = OpenApiResponse(
    response=ErrorSerializer,
    description="phone_exists / invalid_state / last_full_admin",
)


class AdminListCreateView(generics.ListAPIView):
    permission_classes = [require(rights_service.GERER_ADMINS)]
    serializer_class = AdminSerializer
    http_method_names = ["get", "post", "options"]

    def get_queryset(self):
        return admin_service.list_queryset()

    @extend_schema(
        tags=["admin"], operation_id="admin_admins_list",
        description="Comptes ayant un rôle d'administration, numéros masqués, paginés.",
        responses={200: AdminSerializer(many=True), **_ERRORS},
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    @extend_schema(
        tags=["admin"], operation_id="admin_admins_create", request=AdminCreateSerializer,
        description=(
            "Crée un compte Validateur ou Administrateur complet (jamais d'auto-inscription). "
            "Un mot de passe temporaire est généré et renvoyé UNE SEULE FOIS "
            "(`temporary_password`) ; il n'est ni stocké en clair ni journalisé. Le changement "
            "de ce mot de passe n'est pas imposé à la première connexion. Un numéro déjà "
            "utilisé est refusé (409 `phone_exists`). Audit `attribution_role`."
        ),
        responses={201: AdminCreatedSerializer, 400: _BAD, 409: _STATE, **_ERRORS},
    )
    def post(self, request):
        serializer = AdminCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user, password = admin_service.create_admin(request.user, **serializer.validated_data)
        response = Response(
            AdminCreatedSerializer(user, context={"temporary_password": password}).data,
            status=201,
        )
        response["Cache-Control"] = "no-store"
        return response


class AdminDetailView(APIView):
    permission_classes = [require(rights_service.GERER_ADMINS)]
    http_method_names = ["patch", "delete", "options"]

    @extend_schema(
        tags=["admin"], operation_id="admin_admins_update_role", request=AdminRoleSerializer,
        description=("Change le rôle d'un administrateur. Pas sur soi-même ; le dernier "
                     "Administrateur complet actif ne peut pas être rétrogradé. Audit "
                     "`attribution_role`."),
        responses={200: AdminSerializer, 400: _BAD, 404: _NOT_FOUND, 409: _STATE, **_ERRORS},
    )
    def patch(self, request, pk):
        serializer = AdminRoleSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = admin_service.change_role(request.user, pk, serializer.validated_data["role"])
        return Response(AdminSerializer(user).data)

    @extend_schema(
        tags=["admin"], operation_id="admin_admins_remove", request=AdminRemoveSerializer,
        description=("Retire tout rôle d'administration (le compte n'est pas supprimé), motif "
                     "obligatoire ; jetons de rafraîchissement invalidés. Pas sur soi-même ; "
                     "pas sur le dernier Administrateur complet actif. Audit `retrait_role`."),
        responses={200: AdminSerializer, 400: _BAD, 404: _NOT_FOUND, 409: _STATE, **_ERRORS},
    )
    def delete(self, request, pk):
        serializer = AdminRemoveSerializer(data=request.data if request.data else {})
        serializer.is_valid(raise_exception=True)
        user = admin_service.remove_admin(
            request.user, pk, serializer.validated_data.get("reason", "")
        )
        return Response(AdminSerializer(user).data)
