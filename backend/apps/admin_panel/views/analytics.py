"""GET /api/admin/analytics/searches/ et /calls/ (T074c, lecture seule, peut_voir_comptes)."""
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.serializers.otp import ErrorSerializer
from apps.admin_panel.permissions import require
from apps.admin_panel.serializers.analytics import (
    CallAnalyticsSerializer,
    SearchAnalyticsSerializer,
)
from apps.admin_panel.services import analytics_service, rights_service

_ERRORS = {
    400: OpenApiResponse(response=ErrorSerializer, description="invalid_days"),
    401: OpenApiResponse(response=ErrorSerializer, description="Jeton absent ou invalide"),
    403: OpenApiResponse(
        response=ErrorSerializer,
        description="Pas administrateur, sans groupe, sans la permission, ou compte bloqué",
    ),
}
_DAYS = OpenApiParameter(
    "days", int, description="Fenêtre en jours calendaires, aujourd'hui compris : 1 à 90, "
                             "7 par défaut")


class _AnalyticsView(APIView):
    permission_classes = [require(rights_service.VOIR_COMPTES)]
    http_method_names = ["get", "options"]
    serializer_class = None
    compute = None

    def get(self, request):
        days = analytics_service.parse_days(request.query_params.get("days"))
        response = Response(self.serializer_class(type(self).compute(days)).data)
        response["Cache-Control"] = "no-store"
        return response


class SearchAnalyticsView(_AnalyticsView):
    serializer_class = SearchAnalyticsSerializer
    compute = staticmethod(analytics_service.searches)

    @extend_schema(
        tags=["admin"], operation_id="admin_analytics_searches", parameters=[_DAYS],
        description=("Termes de recherche les plus fréquents et recherches sans résultat "
                     "(50 termes au plus, par fréquence). Agrégats seulement : jamais de compte "
                     "ni de numéro ; un terme contenant 6 chiffres ou plus est écarté."),
        responses={200: SearchAnalyticsSerializer, **_ERRORS},
    )
    def get(self, request):
        return super().get(request)


class CallAnalyticsView(_AnalyticsView):
    serializer_class = CallAnalyticsSerializer
    compute = staticmethod(analytics_service.calls)

    @extend_schema(
        tags=["admin"], operation_id="admin_analytics_calls", parameters=[_DAYS],
        description=("Appels par jour (zéros compris), par opérateur (orange, mtn, unknown), "
                     "par plateforme et par canal. Agrégats seulement : ni appelant ni "
                     "commerçant identifiable."),
        responses={200: CallAnalyticsSerializer, **_ERRORS},
    )
    def get(self, request):
        return super().get(request)
