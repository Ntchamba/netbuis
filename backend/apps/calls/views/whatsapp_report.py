"""POST /api/calls/whatsapp-report/ : « ce numéro n'a pas WhatsApp »."""
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.calls.serializers.feedback import (
    WhatsAppReportResponseSerializer,
    WhatsAppReportSerializer,
)
from apps.calls.services.feedback_service import report_no_whatsapp
from apps.calls.views.mixins import NoStoreMixin


class WhatsAppReportView(NoStoreMixin, APIView):
    @extend_schema(
        operation_id="calls_whatsapp_report", tags=["calls"], request=WhatsAppReportSerializer,
        responses={200: WhatsAppReportResponseSerializer,
                   400: OpenApiResponse(description="invalid"),
                   401: OpenApiResponse(description="non connecté"),
                   404: OpenApiResponse(
                       description="not_found : commerce inconnu ou lien WhatsApp jamais reçu")},
        description=(
            "Signale que le numéro n'a pas WhatsApp. Il faut avoir reçu le lien WhatsApp de ce "
            "commerce. Un compte compte une fois ; à 3 comptes distincts, WhatsApp est désactivé."
        ),
    )
    def post(self, request):
        data = WhatsAppReportSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        report_no_whatsapp(request.user, data.validated_data["business_id"])
        return Response({"recorded": True})
