"""POST /api/calls/{id}/feedback/ et GET /api/calls/history/."""
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework.generics import ListAPIView
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.calls.serializers.feedback import (
    FeedbackResponseSerializer,
    FeedbackSerializer,
    HistorySerializer,
)
from apps.calls.services.feedback_service import save_feedback
from apps.calls.services.history_service import caller_history
from apps.calls.views.mixins import NoStoreMixin


class FeedbackView(NoStoreMixin, APIView):
    @extend_schema(
        operation_id="calls_feedback", tags=["calls"], request=FeedbackSerializer,
        responses={200: FeedbackResponseSerializer, 400: OpenApiResponse(description="invalid"),
                   401: OpenApiResponse(description="non connecté"),
                   404: OpenApiResponse(description="not_found : appel d'un autre compte")},
        description=(
            "Résultat de l'appel (abouti, pas de réponse, mauvais numéro). Réservé à l'appelant ; "
            "modifiable : le dernier choix est conservé."
        ),
    )
    def post(self, request, pk):
        data = FeedbackSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        feedback = save_feedback(request.user, pk, data.validated_data["outcome"])
        return Response({"call_id": feedback.call_id, "outcome": feedback.outcome})


class HistoryView(NoStoreMixin, ListAPIView):
    serializer_class = HistorySerializer

    def get_queryset(self):
        return caller_history(self.request.user)

    @extend_schema(
        operation_id="calls_history", tags=["calls"],
        responses={200: HistorySerializer(many=True)},
        description=(
            "Mes appels à l'équipe NetBuis (sessions) et mes liens WhatsApp, 20 par page, "
            "sans aucun numéro."
        ),
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)
