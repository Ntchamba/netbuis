"""POST /api/auth/otp/request/ et /api/auth/otp/verify/ (zone sensible)."""
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.serializers.otp import (
    ErrorSerializer,
    OtpRequestResponseSerializer,
    OtpRequestSerializer,
    OtpVerifyResponseSerializer,
    OtpVerifySerializer,
)
from apps.accounts.services.otp_service import (
    OTP_LIFETIME,
    TooManyRequests,
    parse_phone,
    request_code,
    verify_code,
)
from apps.accounts.services.token_service import issue_tokens
from apps.core.throttling import OtpRateThrottle, OtpVerifyRateThrottle


def _error(description):
    return OpenApiResponse(response=ErrorSerializer, description=description)


class _PublicOtpView(APIView):
    # Pas d'authentification : un jeton envoyé par erreur ne doit ni bloquer ni contourner.
    authentication_classes = []
    permission_classes = [AllowAny]

    def throttled(self, request, wait):
        raise TooManyRequests(wait)


class OtpRequestView(_PublicOtpView):
    throttle_classes = [OtpRateThrottle]  # 10 demandes / heure / IP

    @extend_schema(
        tags=["auth"],
        request=OtpRequestSerializer,
        responses={
            202: OtpRequestResponseSerializer,
            400: _error("invalid_phone : numéro non camerounais mobile ; invalid : champ manquant"),
            429: _error(
                "too_many_requests : 3 demandes / 10 min par numéro, 10 / heure par IP, "
                "ou numéro bloqué 1 heure après 5 codes faux (en-tête Retry-After en secondes)"
            ),
        },
    )
    def post(self, request):
        serializer = OtpRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        request_code(parse_phone(serializer.validated_data["phone"]))
        expires_in = int(OTP_LIFETIME.total_seconds())
        return Response({"expires_in": expires_in}, status=status.HTTP_202_ACCEPTED)


class OtpVerifyView(_PublicOtpView):
    throttle_classes = [OtpVerifyRateThrottle]  # 30 vérifications / heure / IP

    @extend_schema(
        tags=["auth"],
        request=OtpVerifySerializer,
        responses={
            200: OtpVerifyResponseSerializer,
            400: _error(
                "invalid_phone ; otp_invalid : code faux, déjà utilisé ou remplacé ; "
                "otp_expired : plus de 5 min ; invalid : champ manquant"
            ),
            403: _error("account_blocked / account_deleted : « Contactez le support »"),
            429: _error(
                "too_many_requests : 5 essais ratés (demander un nouveau code), "
                "30 vérifications / heure par IP, ou numéro bloqué 1 heure après 5 codes faux "
                "(en-tête Retry-After en secondes)"
            ),
        },
    )
    def post(self, request):
        serializer = OtpVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone = parse_phone(serializer.validated_data["phone"])
        user, is_new = verify_code(phone, serializer.validated_data["code"])
        return Response({**issue_tokens(user), "is_new": is_new})
