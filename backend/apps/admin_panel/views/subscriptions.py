"""Abonnements.

- GET  /api/admin/subscriptions/  liste (T074c, peut_voir_comptes)
- POST /api/admin/subscriptions/  accorde un abonnement (T110, peut_accorder_abonnement :
  Administrateur complet seulement, motif obligatoire, audit `accord_abonnement`)
"""
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import generics, status
from rest_framework.response import Response

from apps.accounts.serializers.otp import ErrorSerializer
from apps.admin_panel.permissions import require
from apps.admin_panel.serializers.subscription import (
    SubscriptionGrantedSerializer,
    SubscriptionGrantSerializer,
    SubscriptionRowSerializer,
)
from apps.admin_panel.services import rights_service, subscription_service
from apps.core.models.platform_setting import SettingKey
from apps.core.services.settings_service import get_setting


class SubscriptionListView(generics.ListAPIView):
    serializer_class = SubscriptionRowSerializer
    http_method_names = ["get", "post", "options"]

    def get_permissions(self):
        code = (rights_service.ACCORDER_ABONNEMENT if self.request.method == "POST"
                else rights_service.VOIR_COMPTES)
        return [require(code)()]

    def get_queryset(self):
        return subscription_service.list_queryset(self.request.query_params.get("filter", "all"))

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["threshold"] = get_setting(SettingKey.SEUIL_APPELS_ABONNEMENT)
        return context

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = "no-store"
        return response

    @extend_schema(
        tags=["admin"], operation_id="admin_subscriptions_list",
        parameters=[OpenApiParameter(
            "filter", str, enum=list(subscription_service.FILTERS),
            description="all (défaut), subscribed, unsubscribed, high_traffic (non abonnés "
                        "au-dessus du seuil `seuil_appels_abonnement` sur 24 h)")],
        description=("Comptes business actifs, paginés, les plus sollicités d'abord. Numéro "
                     "toujours masqué."),
        responses={
            200: SubscriptionRowSerializer(many=True),
            400: OpenApiResponse(response=ErrorSerializer, description="invalid_filter"),
            401: OpenApiResponse(response=ErrorSerializer, description="Jeton absent ou invalide"),
            403: OpenApiResponse(response=ErrorSerializer, description="Droit manquant"),
        },
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    @extend_schema(
        tags=["admin"], operation_id="admin_subscriptions_grant",
        request=SubscriptionGrantSerializer,
        description=(
            "Accorde un abonnement à la main (aucun paiement), à partir de maintenant, pour "
            "1 à 366 jours. Administrateur complet seulement ; motif obligatoire ; audit "
            "`accord_abonnement` (cible : l'abonnement) écrit dans la même transaction. Effet "
            "immédiat : plafonds levés, commerce classé avant les autres. Le compte doit être "
            "actif (409 `business_not_active`) et sans abonnement en cours (409 "
            "`already_subscribed` : aucune prolongation ni cumul). Aucun numéro dans la réponse."
        ),
        responses={
            201: SubscriptionGrantedSerializer,
            400: OpenApiResponse(response=ErrorSerializer,
                                 description="validation_error (durée, motif, identifiant)"),
            401: OpenApiResponse(response=ErrorSerializer, description="Jeton absent ou invalide"),
            403: OpenApiResponse(response=ErrorSerializer, description="Droit manquant"),
            404: OpenApiResponse(response=ErrorSerializer, description="not_found"),
            409: OpenApiResponse(response=ErrorSerializer,
                                 description="business_not_active / already_subscribed"),
        },
    )
    def post(self, request, *args, **kwargs):
        serializer = SubscriptionGrantSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        subscription = subscription_service.grant(
            request.user, data["business_id"], data["duration_days"], data["reason"])
        response = Response(SubscriptionGrantedSerializer(subscription).data,
                            status=status.HTTP_201_CREATED)
        response["Cache-Control"] = "no-store"
        return response
