"""GET /api/admin/subscriptions/ (T074c, lecture seule, peut_voir_comptes)."""
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import generics

from apps.accounts.serializers.otp import ErrorSerializer
from apps.admin_panel.permissions import require
from apps.admin_panel.serializers.subscription import SubscriptionRowSerializer
from apps.admin_panel.services import rights_service, subscription_service
from apps.core.models.platform_setting import SettingKey
from apps.core.services.settings_service import get_setting


class SubscriptionListView(generics.ListAPIView):
    permission_classes = [require(rights_service.VOIR_COMPTES)]
    serializer_class = SubscriptionRowSerializer
    http_method_names = ["get", "options"]

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
