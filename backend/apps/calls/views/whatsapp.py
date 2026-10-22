"""POST /api/calls/whatsapp/ : lien WhatsApp du commerce (D-25 : l'appel téléphonique a disparu)."""
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework import exceptions
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.calls.serializers.sessions import CallErrorSerializer
from apps.calls.serializers.whatsapp import WhatsAppResponseSerializer, WhatsAppSerializer
from apps.calls.services.call_service import not_authenticated, open_whatsapp
from apps.calls.views.mixins import NoStoreMixin


class WhatsAppView(NoStoreMixin, APIView):
    # Les contrôles (connexion, blocage) sont faits par le service pour renvoyer les codes
    # de la liste fermée de l'API (inchangés depuis T050).
    permission_classes = [AllowAny]

    def handle_exception(self, exc):
        if isinstance(exc, exceptions.NotAuthenticated | exceptions.AuthenticationFailed):
            exc = not_authenticated()
        return super().handle_exception(exc)

    @extend_schema(
        operation_id="calls_whatsapp", tags=["calls"], request=WhatsAppSerializer,
        responses={
            200: WhatsAppResponseSerializer, 400: OpenApiResponse(description="invalid"),
            401: OpenApiResponse(description="non connecté"),
            403: OpenApiResponse(CallErrorSerializer, description="ACCOUNT_BLOCKED, OWN_BUSINESS"),
            404: OpenApiResponse(CallErrorSerializer, description="BUSINESS_NOT_ACTIVE"),
            409: OpenApiResponse(CallErrorSerializer, description="CHANNEL_UNAVAILABLE"),
            429: OpenApiResponse(CallErrorSerializer, description="RATE_LIMITED"),
        },
        description=(
            "Vérifie les droits et la limite anti-aspiration, enregistre l'ouverture, puis "
            "renvoie le lien WhatsApp du commerce POUR CET USAGE SEULEMENT "
            "(Cache-Control: no-store). Le numéro n'est jamais renvoyé sous une autre forme."
        ),
    )
    def post(self, request):
        if not (request.user and request.user.is_authenticated):
            raise not_authenticated()
        data = WhatsAppSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        result = open_whatsapp(
            request.user, data.validated_data["business_id"], data.validated_data["platform"]
        )
        return Response(WhatsAppResponseSerializer(result).data)
