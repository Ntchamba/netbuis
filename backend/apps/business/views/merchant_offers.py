"""GET/POST /api/business/me/offers/ et PATCH/DELETE /api/business/me/offers/<id>/ (T037).

Réservé au propriétaire d'un compte business **actif**. Le profil vient de `request.user`,
jamais du corps de la requête : l'offre d'un autre commerçant renvoie 404.
"""
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import OpenApiResponse, extend_schema, extend_schema_view
from rest_framework import generics, status
from rest_framework.response import Response

from apps.accounts.serializers.otp import ErrorSerializer
from apps.business.permissions import IsMerchantOwner
from apps.business.serializers.offer import OfferSerializer
from apps.business.services import offer_service

_ERRORS = {
    401: OpenApiResponse(
        response=ErrorSerializer,
        description="not_authenticated / token_not_valid : jeton d'accès absent, faux ou expiré",
    ),
    403: OpenApiResponse(
        response=ErrorSerializer,
        description=(
            "business_not_active : compte business en attente ou rejeté ; "
            "account_blocked / account_deleted"
        ),
    ),
    404: OpenApiResponse(
        response=ErrorSerializer,
        description="no_business : pas de compte business ; not_found : offre introuvable",
    ),
}
_INVALID = OpenApiResponse(
    response=ErrorSerializer,
    description="invalid : `fields` donne l'erreur de chaque champ (prix négatif, 5 photos…)",
)


@extend_schema_view(
    get=extend_schema(
        tags=["business"], operation_id="business_me_offers_list",
        responses={200: OfferSerializer(many=True), **_ERRORS},
    ),
    post=extend_schema(
        tags=["business"], operation_id="business_me_offers_create",
        responses={201: OfferSerializer, 400: _INVALID, **_ERRORS},
    ),
)
class MerchantOfferListView(generics.ListCreateAPIView):
    serializer_class = OfferSerializer
    permission_classes = [IsMerchantOwner]

    def get_queryset(self):
        return offer_service.own_offers(self.request.user)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        offer = offer_service.create_offer(request.user, serializer.validated_data)
        return Response(self.get_serializer(offer).data, status=status.HTTP_201_CREATED)


@extend_schema_view(
    patch=extend_schema(
        tags=["business"], operation_id="business_me_offers_partial_update",
        responses={200: OfferSerializer, 400: _INVALID, **_ERRORS},
    ),
    delete=extend_schema(
        tags=["business"], operation_id="business_me_offers_destroy",
        responses={204: None, **_ERRORS},
    ),
)
class MerchantOfferDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = OfferSerializer
    permission_classes = [IsMerchantOwner]
    http_method_names = ["patch", "delete", "options"]

    def get_queryset(self):
        return offer_service.own_offers(self.request.user)

    def get_object(self):
        offer = get_object_or_404(self.get_queryset(), pk=self.kwargs["pk"])
        self.check_object_permissions(self.request, offer.profile)
        return offer

    def partial_update(self, request, *args, **kwargs):
        offer = self.get_object()
        serializer = self.get_serializer(offer, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        offer = offer_service.update_offer(offer, serializer.validated_data)
        return Response(self.get_serializer(offer).data)
