"""POST /api/auth/refresh/ et POST /api/auth/logout/ (zone sensible).

Décision D-01 : l'application mobile envoie {"refresh": …} dans le corps et reçoit le
nouveau couple dans le corps ; le dashboard n'envoie rien dans le corps, le jeton est lu
dans le cookie HttpOnly netbuis_refresh et le nouveau y est reposé.
Les deux routes s'utilisent sans jeton d'accès (il peut avoir expiré).
"""
from django.conf import settings
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.serializers.otp import ErrorSerializer
from apps.accounts.serializers.token import RefreshRequestSerializer, RefreshResponseSerializer
from apps.accounts.services.token_service import (
    TokenInvalid,
    delete_refresh_cookie,
    revoke_refresh,
    rotate_refresh,
    set_refresh_cookie,
)

REFRESH_COOKIE = OpenApiParameter(
    "netbuis_refresh",
    str,
    location=OpenApiParameter.COOKIE,
    required=False,
    description="Dashboard : jeton de rafraîchissement (cookie HttpOnly posé par admin/login)",
)


def _read_refresh(request) -> tuple[str, bool]:
    """(jeton, vient_du_cookie). Le corps (mobile) passe avant le cookie (dashboard)."""
    serializer = RefreshRequestSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    body = serializer.validated_data.get("refresh")
    if body:
        return body, False
    cookie = request.COOKIES.get(settings.REFRESH_COOKIE_NAME)
    if cookie:
        return cookie, True
    raise TokenInvalid()


class _PublicTokenView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def handle_exception(self, exc):
        response = super().handle_exception(exc)
        # Cookie refusé (faux, expiré, déjà utilisé, compte bloqué) : le navigateur l'oublie.
        has_cookie = settings.REFRESH_COOKIE_NAME in self.request.COOKIES
        if response.status_code in (401, 403) and has_cookie:
            delete_refresh_cookie(response)
        return response


class RefreshView(_PublicTokenView):
    @extend_schema(
        tags=["auth"],
        request=RefreshRequestSerializer,
        parameters=[REFRESH_COOKIE],
        responses={
            200: OpenApiResponse(
                response=RefreshResponseSerializer,
                description=(
                    "Nouveau couple ; l'ancien jeton de rafraîchissement n'est plus valable. "
                    "Dashboard : seul access est dans le corps, le cookie est reposé."
                ),
            ),
            401: OpenApiResponse(
                response=ErrorSerializer,
                description="token_invalid : jeton absent, faux, expiré ou déjà utilisé",
            ),
            403: OpenApiResponse(
                response=ErrorSerializer,
                description="account_blocked / account_deleted : « Contactez le support »",
            ),
        },
    )
    def post(self, request):
        raw, from_cookie = _read_refresh(request)
        tokens = rotate_refresh(raw)
        if from_cookie:
            response = Response({"access": tokens["access"]})
            set_refresh_cookie(response, tokens["refresh"])
            return response
        return Response(tokens)


class LogoutView(_PublicTokenView):
    @extend_schema(
        tags=["auth"],
        request=RefreshRequestSerializer,
        parameters=[REFRESH_COOKIE],
        responses={
            204: OpenApiResponse(
                description="Déconnecté : le jeton de rafraîchissement ne peut plus servir ; "
                "le cookie du dashboard est effacé."
            ),
            401: OpenApiResponse(
                response=ErrorSerializer,
                description="token_invalid : jeton absent, faux, expiré ou déjà invalidé",
            ),
        },
    )
    def post(self, request):
        raw, _ = _read_refresh(request)
        revoke_refresh(raw)
        response = Response(status=status.HTTP_204_NO_CONTENT)
        delete_refresh_cookie(response)
        return response
