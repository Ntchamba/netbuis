"""Réponses du forum : personnalisées (contenus que l'appelant a signalés exclus) donc jamais
mises en cache partagé."""
from drf_spectacular.utils import OpenApiResponse

from apps.accounts.serializers.otp import ErrorSerializer


class NoStoreMixin:
    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = "no-store"
        return response


ERR_401 = OpenApiResponse(response=ErrorSerializer, description="Non connecté.")
ERR_403 = OpenApiResponse(
    response=ErrorSerializer,
    description="account_blocked / account_deleted ; business_not_active : compte business "
                "en attente ou rejeté",
)
ERR_404 = OpenApiResponse(
    response=ErrorSerializer,
    description="not_found : contenu absent, masqué, supprimé ou signalé par vous ; "
                "no_business : pas de compte business",
)
ERR_400 = OpenApiResponse(
    response=ErrorSerializer,
    description="invalid : `fields` donne l'erreur de chaque champ ; SUBSCRIPTION_REQUIRED : "
                "plafond de publications actives sans abonnement",
)
ERR_429 = OpenApiResponse(
    response=ErrorSerializer,
    description="daily_post_limit : 5 publications par 24 h ; comment_rate_limit : "
                "10 commentaires par 10 minutes",
)
