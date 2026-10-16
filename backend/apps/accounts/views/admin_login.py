"""POST /api/auth/admin/login/ (zone sensible : revue ligne par ligne).

Téléphone + mot de passe, comptes is_admin seulement (connexion du dashboard).
Une seule erreur, identique (statut, code, texte), que le compte existe ou non,
que le mot de passe soit faux, que le compte ne soit pas administrateur, ou qu'il
soit bloqué ou supprimé. 5 essais ratés par IP sur 15 min, puis 429.
Réponse : jeton d'accès dans le corps, jeton de rafraîchissement dans le cookie (D-01).
"""
from django.contrib.auth import authenticate
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import BaseThrottle
from rest_framework.views import APIView

from apps.accounts.serializers.otp import ErrorSerializer
from apps.accounts.serializers.token import AccessResponseSerializer, AdminLoginSerializer
from apps.accounts.services.otp_service import TooManyRequests
from apps.accounts.services.rate_limit import admin_login_release, admin_login_reserve
from apps.accounts.services.token_service import issue_tokens, set_refresh_cookie
from apps.core.exceptions import ApiError
from apps.core.utils.phone import normalize_phone


class InvalidCredentials(ApiError):
    status_code = status.HTTP_401_UNAUTHORIZED
    default_code = "invalid_credentials"
    default_detail = "Numéro ou mot de passe incorrect."


def client_ip(request) -> str:
    """Même identification de l'IP que les throttles DRF (réglage NUM_PROXIES)."""
    return BaseThrottle().get_ident(request)


class AdminLoginView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    @extend_schema(
        tags=["auth"],
        request=AdminLoginSerializer,
        responses={
            200: OpenApiResponse(
                response=AccessResponseSerializer,
                description=(
                    "Connecté. En-tête Set-Cookie : netbuis_refresh (HttpOnly, SameSite=Lax, "
                    "Secure hors développement, Path=/api/auth/, 30 jours)."
                ),
            ),
            400: OpenApiResponse(
                response=ErrorSerializer, description="invalid : champ manquant"
            ),
            401: OpenApiResponse(
                response=ErrorSerializer,
                description=(
                    "invalid_credentials : « Numéro ou mot de passe incorrect. » — même "
                    "réponse si le compte n'existe pas, n'est pas administrateur, est bloqué "
                    "ou supprimé"
                ),
            ),
            429: OpenApiResponse(
                response=ErrorSerializer,
                description=(
                    "too_many_requests : 5 essais ratés en 15 min depuis cette IP "
                    "(en-tête Retry-After en secondes)"
                ),
            ),
        },
    )
    def post(self, request):
        serializer = AdminLoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        ip = client_ip(request)
        # Essai réservé AVANT d'évaluer le mot de passe : tient en simultané.
        wait = admin_login_reserve(ip)
        if wait:
            raise TooManyRequests(wait)
        raw_phone = serializer.validated_data["phone"]
        try:
            phone = normalize_phone(raw_phone)
        except ValueError:
            phone = raw_phone  # aucun compte ne correspond : même erreur, même temps de calcul
        # AdminOnlyBackend : mot de passe juste ET is_admin ET user.can_login().
        user = authenticate(request, phone=phone, password=serializer.validated_data["password"])
        if user is None or not (user.is_admin and user.can_login()):
            raise InvalidCredentials()  # la place réservée reste comptée comme échec
        admin_login_release(ip)
        tokens = issue_tokens(user)
        response = Response({"access": tokens["access"]})
        set_refresh_cookie(response, tokens["refresh"])
        return response
