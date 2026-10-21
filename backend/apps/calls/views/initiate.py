"""POST /api/calls/initiate/ (seul endroit qui renvoie le numéro d'un commerçant)."""
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework import exceptions, status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.calls.serializers.initiate import (
    ErrorCodeSerializer,
    InitiateResponseSerializer,
    InitiateSerializer,
)
from apps.calls.services.call_service import initiate_call, not_authenticated

_REFUSALS = {
    401: OpenApiResponse(ErrorCodeSerializer, description="NOT_AUTHENTICATED"),
    403: OpenApiResponse(ErrorCodeSerializer, description="ACCOUNT_BLOCKED, OWN_BUSINESS"),
    404: OpenApiResponse(ErrorCodeSerializer, description="BUSINESS_NOT_ACTIVE"),
    409: OpenApiResponse(ErrorCodeSerializer, description="CHANNEL_UNAVAILABLE"),
    429: OpenApiResponse(ErrorCodeSerializer, description="RATE_LIMITED"),
}


class InitiateCallView(APIView):
    # Les contrôles (connexion, blocage) sont faits par le service pour renvoyer les codes
    # de la liste fermée de l'API.
    permission_classes = [AllowAny]

    def handle_exception(self, exc):
        if isinstance(exc, exceptions.NotAuthenticated | exceptions.AuthenticationFailed):
            exc = not_authenticated()
        return super().handle_exception(exc)

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = "no-store"
        return response

    @extend_schema(
        operation_id="calls_initiate",
        tags=["calls"],
        request=InitiateSerializer,
        responses={200: InitiateResponseSerializer, 400: OpenApiResponse(description="invalid"),
                   **_REFUSALS},
        description=(
            "Vérifie les droits et la limite anti-aspiration, enregistre l'appel, puis renvoie "
            "le numéro du commerçant POUR CET APPEL SEULEMENT (Cache-Control: no-store)."
        ),
    )
    def post(self, request):
        if not (request.user and request.user.is_authenticated):
            raise not_authenticated()
        data = InitiateSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        result = initiate_call(
            request.user,
            business_id=data.validated_data["business_id"],
            channel=data.validated_data["channel"],
            platform=data.validated_data["platform"],
            operator=data.validated_data.get("operator", ""),
        )
        return Response(InitiateResponseSerializer(result).data, status=status.HTTP_200_OK)
