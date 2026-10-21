"""GET /api/admin/stats/ : chiffres de la vue d'ensemble (T073)."""
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.serializers.otp import ErrorSerializer
from apps.admin_panel.permissions import require
from apps.admin_panel.serializers.stats import AdminStatsSerializer
from apps.admin_panel.services import rights_service, stats_service


class AdminStatsView(APIView):
    permission_classes = [require(rights_service.VOIR_COMPTES)]
    http_method_names = ["get", "options"]

    @extend_schema(
        tags=["admin"], operation_id="admin_stats_retrieve",
        description=(
            "Chiffres de la vue d'ensemble. Fenêtres de 7 jours glissantes. Comptes à fort "
            "trafic : appels des dernières 24 h au-dessus du seuil `seuil_appels_abonnement`, "
            "non abonnés ; id, nom et compteur seulement (jamais de numéro). "
            "`revenue_month` vaut 0 avec `unavailable: true` tant que les paiements ne sont "
            "pas faits."
        ),
        responses={
            200: AdminStatsSerializer,
            401: OpenApiResponse(response=ErrorSerializer, description="Jeton absent ou invalide"),
            403: OpenApiResponse(
                response=ErrorSerializer,
                description="Pas administrateur, sans groupe, sans la permission, ou compte bloqué",
            ),
        },
    )
    def get(self, request):
        response = Response(AdminStatsSerializer(stats_service.compute()).data)
        response["Cache-Control"] = "no-store"
        return response
