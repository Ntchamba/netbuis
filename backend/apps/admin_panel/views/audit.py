"""GET /api/admin/audit/ (T074c, lecture seule, peut_voir_comptes)."""
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import generics

from apps.accounts.serializers.otp import ErrorSerializer
from apps.admin_panel.models import AuditAction
from apps.admin_panel.permissions import require
from apps.admin_panel.serializers.audit import AuditEntrySerializer
from apps.admin_panel.services import audit_read_service, rights_service


class AuditListView(generics.ListAPIView):
    permission_classes = [require(rights_service.VOIR_COMPTES)]
    serializer_class = AuditEntrySerializer
    http_method_names = ["get", "options"]

    def get_queryset(self):
        p = self.request.query_params
        return audit_read_service.list_queryset(
            admin=p.get("admin"), action=p.get("action"),
            date_from=p.get("from"), date_to=p.get("to"))

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = "no-store"
        return response

    @extend_schema(
        tags=["admin"], operation_id="admin_audit_list",
        parameters=[
            OpenApiParameter("admin", int, description="Identifiant de l'administrateur"),
            OpenApiParameter("action", str, enum=list(AuditAction.values)),
            OpenApiParameter("from", str, description="Jour AAAA-MM-JJ, inclus (fuseau du projet)"),
            OpenApiParameter("to", str, description="Jour AAAA-MM-JJ, inclus (fuseau du projet)"),
        ],
        description=("Journal d'audit en lecture seule, du plus récent au plus ancien, paginé. "
                     "Le motif est affiché mais tout numéro, code, jeton ou lien y est masqué."),
        responses={
            200: AuditEntrySerializer(many=True),
            400: OpenApiResponse(response=ErrorSerializer, description="invalid_filter"),
            401: OpenApiResponse(response=ErrorSerializer, description="Jeton absent ou invalide"),
            403: OpenApiResponse(response=ErrorSerializer, description="Droit manquant"),
        },
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)
