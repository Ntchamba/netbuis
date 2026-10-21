"""GET /api/business/<id>/ — fiche publique d'un commerce (T047b).

Connecté et non bloqué. Seuls les profils `visible()` (actifs, propriétaire utilisable) sont
servis ; sinon 404. Jamais de numéro ni de pièce d'identité. Chaque ouverture compte pour une
vue par compte et par jour (le propriétaire ne gonfle pas ses propres vues).
"""
from django.db import transaction
from django.db.models import F
from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import OpenApiResponse, extend_schema, extend_schema_view
from rest_framework import generics
from rest_framework.response import Response

from apps.accounts.permissions import IsAuthenticatedNotBlocked
from apps.accounts.serializers.otp import ErrorSerializer
from apps.business.models import BusinessProfile, ProfileView
from apps.business.serializers.public_detail import PublicBusinessSerializer


def count_view(profile: BusinessProfile, viewer) -> bool:
    """Compte la vue si ce compte n'a pas déjà vu ce profil aujourd'hui. Atomique."""
    if viewer.pk == profile.owner_id:
        return False
    with transaction.atomic():
        _, created = ProfileView.objects.get_or_create(
            profile=profile, viewer=viewer, day=timezone.localdate()
        )
        if created:
            BusinessProfile.objects.filter(pk=profile.pk).update(views_count=F("views_count") + 1)
    return created


@extend_schema_view(get=extend_schema(
    tags=["business"], operation_id="business_public_detail",
    responses={
        200: PublicBusinessSerializer,
        401: OpenApiResponse(response=ErrorSerializer, description="Non connecté."),
        403: OpenApiResponse(
            response=ErrorSerializer, description="account_blocked / account_deleted"
        ),
        404: OpenApiResponse(
            response=ErrorSerializer, description="not_found : profil absent ou non actif"
        ),
    },
))
class PublicBusinessView(generics.RetrieveAPIView):
    permission_classes = [IsAuthenticatedNotBlocked]
    serializer_class = PublicBusinessSerializer

    def get_queryset(self):
        return BusinessProfile.objects.visible().select_related(
            "zone", "secteur", "categorie_service", "structure_type"
        ).prefetch_related("offers")

    def retrieve(self, request, *args, **kwargs):
        profile = get_object_or_404(self.get_queryset(), pk=kwargs["pk"])
        count_view(profile, request.user)
        return Response(self.get_serializer(profile).data)
