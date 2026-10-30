"""GET / PATCH / DELETE /api/me/ : le compte de l'utilisateur connecté (T008).

DELETE = suppression DOUCE par l'utilisateur lui-même (D-09) : is_deleted et deleted_at
sont posés, tous ses jetons de rafraîchissement sont invalidés, ses données restent.
Son compte business disparaît avec lui (un propriétaire is_deleted est retiré partout :
règle appliquée par la recherche, la carte et la fiche, T026). S'il se reconnecte avec
le même numéro, verify répond 403 account_deleted « Contactez le support ».
"""
from django.db import transaction
from django.utils import timezone
from drf_spectacular.utils import OpenApiResponse, extend_schema, extend_schema_view
from rest_framework import generics

from apps.accounts.models import User
from apps.accounts.permissions import IsAuthenticatedNotBlocked
from apps.accounts.serializers.otp import ErrorSerializer
from apps.accounts.serializers.user import MeSerializer
from apps.accounts.services.token_service import revoke_all_refresh

_COMMON_ERRORS = {
    401: OpenApiResponse(
        response=ErrorSerializer,
        description="not_authenticated / token_not_valid : jeton d'accès absent, faux ou expiré",
    ),
    403: OpenApiResponse(
        response=ErrorSerializer,
        description="account_blocked / account_deleted : « Contactez le support »",
    ),
}


@extend_schema_view(
    get=extend_schema(tags=["account"], responses={200: MeSerializer, **_COMMON_ERRORS}),
    patch=extend_schema(
        tags=["account"],
        responses={
            200: MeSerializer,
            400: OpenApiResponse(
                response=ErrorSerializer,
                description="invalid : nom trop long ou langue inconnue (fr, en)",
            ),
            **_COMMON_ERRORS,
        },
    ),
    delete=extend_schema(
        tags=["account"],
        responses={
            204: OpenApiResponse(
                description=(
                    "Compte supprimé (suppression douce) ; tous les jetons sont invalidés. "
                    "Une reconnexion avec ce numéro reçoit « Contactez le support »."
                )
            ),
            **_COMMON_ERRORS,
        },
    ),
)
class MeView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = MeSerializer
    permission_classes = [IsAuthenticatedNotBlocked]
    http_method_names = ["get", "patch", "delete", "head", "options"]

    def get_object(self):
        return self.request.user

    def perform_destroy(self, instance):
        with transaction.atomic():
            user = User.objects.select_for_update().get(pk=instance.pk)
            user.is_deleted = True
            user.deleted_at = timezone.now()
            user.save(update_fields=["is_deleted", "deleted_at", "updated_at"])
            revoke_all_refresh(user)
