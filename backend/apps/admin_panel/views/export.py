"""GET /api/admin/export/accounts.csv (T074, zone sensible) : Administrateur complet seulement."""
from datetime import date

from django.http import StreamingHttpResponse
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework.views import APIView

from apps.accounts.serializers.otp import ErrorSerializer
from apps.admin_panel.permissions import require
from apps.admin_panel.services import export_service, rights_service


class AccountsCsvView(APIView):
    permission_classes = [require(rights_service.EXPORTER)]
    http_method_names = ["get", "options"]

    @extend_schema(
        tags=["admin"], operation_id="admin_export_accounts",
        description=(
            "Export CSV (UTF-8) de tous les comptes : id, nom, téléphone MASQUÉ, type, statut, "
            "langue, administrateur, commerce, statut du dossier, zone, date de création. "
            "Sans numéro complet, CNI, pièces, jetons ni mot de passe. Cellules neutralisées "
            "contre l'injection de formule. Chaque export est audité (`export_comptes`). "
            "`Cache-Control: no-store`."
        ),
        responses={
            (200, "text/csv"): OpenApiResponse(description="Fichier CSV"),
            401: OpenApiResponse(response=ErrorSerializer, description="Jeton absent ou invalide"),
            403: OpenApiResponse(
                response=ErrorSerializer,
                description="Pas administrateur, sans groupe, ou sans peut_exporter"),
        },
    )
    def get(self, request):
        _count, lines = export_service.start_export(request.user)
        response = StreamingHttpResponse(lines, content_type="text/csv; charset=utf-8")
        response["Content-Disposition"] = (
            f'attachment; filename="comptes-{date.today():%Y%m%d}.csv"'
        )
        response["Cache-Control"] = "no-store"
        return response
