"""Espace commerçant : compte business (T026).

- `POST /api/business/` : crée le compte (un seul par utilisateur), en attente de validation.
- `GET` / `PATCH /api/business/me/` : lit / modifie le sien. Pas de DELETE.
Le propriétaire est toujours `request.user` ; le statut n'est jamais fourni par le client.
"""
from drf_spectacular.utils import OpenApiResponse, extend_schema, extend_schema_view
from rest_framework import generics, status
from rest_framework.response import Response

from apps.accounts.serializers.otp import ErrorSerializer
from apps.business.permissions import IsMerchantOwner
from apps.business.serializers.profile import BusinessProfileSerializer
from apps.business.services import profile_service

_ERRORS = {
    401: OpenApiResponse(
        response=ErrorSerializer,
        description="not_authenticated / token_not_valid : jeton d'accès absent, faux ou expiré",
    ),
    403: OpenApiResponse(
        response=ErrorSerializer,
        description="account_blocked / account_deleted : « Contactez le support »",
    ),
}
_INVALID = OpenApiResponse(
    response=ErrorSerializer,
    description=(
        "invalid : `fields` donne l'erreur de chaque champ (champ obligatoire selon le type, "
        "lieu trop haut, valeur inconnue…) ; SUBSCRIPTION_REQUIRED : plus de 3 sous-catégories, "
        "rayons ou spécialités sans abonnement actif"
    ),
)
_NO_BUSINESS = OpenApiResponse(
    response=ErrorSerializer, description="no_business : ce compte n'a pas de compte business"
)


@extend_schema_view(
    post=extend_schema(
        tags=["business"], operation_id="business_create",
        responses={
            201: BusinessProfileSerializer, 400: _INVALID, **_ERRORS,
            409: OpenApiResponse(
                response=ErrorSerializer,
                description="business_exists : ce compte a déjà un compte business",
            ),
        },
    ),
)
class BusinessCreateView(generics.GenericAPIView):
    serializer_class = BusinessProfileSerializer
    http_method_names = ["post", "options"]

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile = profile_service.create_profile(request.user, serializer.validated_data)
        return Response(self.get_serializer(profile).data, status=status.HTTP_201_CREATED)


@extend_schema_view(
    get=extend_schema(
        tags=["business"], operation_id="business_me_retrieve",
        responses={200: BusinessProfileSerializer, 404: _NO_BUSINESS, **_ERRORS},
    ),
    patch=extend_schema(
        tags=["business"], operation_id="business_me_partial_update",
        description=(
            "Règle D-08 sur un compte `actif` : changer réellement le nom, le type ou le lieu "
            "le remet en `en_attente_validation` ; description, photos et le reste "
            "ne demandent pas de nouvelle validation. Le numéro ancré est celui du compte, "
            "imposé par le serveur : il n'est pas modifiable. Un compte `rejete` corrigé "
            "repasse en `en_attente_validation` et son motif est effacé."
        ),
        responses={
            200: BusinessProfileSerializer, 400: _INVALID, 404: _NO_BUSINESS, **_ERRORS
        },
    ),
)
class MerchantProfileView(generics.GenericAPIView):
    serializer_class = BusinessProfileSerializer
    permission_classes = [IsMerchantOwner]
    http_method_names = ["get", "patch", "options"]

    def _own_profile(self):
        profile = profile_service.get_own_profile(self.request.user)
        self.check_object_permissions(self.request, profile)
        return profile

    def get(self, request):
        return Response(self.get_serializer(self._own_profile()).data)

    def patch(self, request):
        profile = self._own_profile()
        serializer = self.get_serializer(profile, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        profile = profile_service.update_profile(profile, serializer.validated_data)
        return Response(self.get_serializer(profile).data)
