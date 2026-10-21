"""Réglages de plateforme (T074, zone sensible).

- GET   /api/admin/settings/        les 5 réglages (Administrateur complet seulement)
- PATCH /api/admin/settings/<key>/  modifie un réglage ; audit `modification_reglage`
"""
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.serializers.otp import ErrorSerializer
from apps.admin_panel.permissions import require
from apps.admin_panel.serializers.admin import SettingSerializer, SettingUpdateSerializer
from apps.admin_panel.services import rights_service, settings_service

_ERRORS = {
    401: OpenApiResponse(response=ErrorSerializer, description="Jeton absent ou invalide"),
    403: OpenApiResponse(
        response=ErrorSerializer,
        description="Pas administrateur, sans groupe, ou sans peut_modifier_reglages",
    ),
}


class SettingListView(APIView):
    permission_classes = [require(rights_service.MODIFIER_REGLAGES)]
    http_method_names = ["get", "options"]

    @extend_schema(
        tags=["admin"], operation_id="admin_settings_list",
        description="Les réglages de la plateforme avec valeur, défaut et bornes.",
        responses={200: SettingSerializer(many=True), **_ERRORS},
    )
    def get(self, request):
        response = Response(SettingSerializer(settings_service.list_settings(), many=True).data)
        response["Cache-Control"] = "no-store"
        return response


class SettingDetailView(APIView):
    permission_classes = [require(rights_service.MODIFIER_REGLAGES)]
    http_method_names = ["patch", "options"]

    @extend_schema(
        tags=["admin"], operation_id="admin_settings_update", request=SettingUpdateSerializer,
        description=("Modifie un réglage (entier entre `min` et `max`). Clé inconnue : 400 "
                     "`unknown_setting` ; valeur hors bornes ou non entière : 400 "
                     "`invalid_value`. Audit `modification_reglage` (clé, ancienne et nouvelle "
                     "valeur)."),
        responses={200: SettingSerializer,
                   400: OpenApiResponse(response=ErrorSerializer,
                                        description="unknown_setting / invalid_value"),
                   **_ERRORS},
    )
    def patch(self, request, key):
        settings_service.check_key(key)
        serializer = SettingUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        result = settings_service.update_setting(
            request.user, key, data["value"], data.get("reason", "")
        )
        return Response(SettingSerializer(result).data)
