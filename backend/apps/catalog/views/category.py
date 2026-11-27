"""Référentiels publics (T021) : GET /api/referentials/sectors/, /service-categories/,
/structure-types/. Lecture seule, sans authentification, éléments actifs seulement, triés par
ordre puis nom. Ce sont de petites listes fixes : un tableau simple, SANS pagination (les écrans
du mobile les chargent en entier)."""
from django.db.models import Prefetch
from drf_spectacular.utils import extend_schema
from rest_framework import generics
from rest_framework.permissions import AllowAny

from apps.catalog.models import Sector, ServiceCategory, StructureType, Subcategory
from apps.catalog.serializers.category import (
    SectorSerializer,
    ServiceCategorySerializer,
    StructureTypeSerializer,
)


class PublicReferentialView(generics.ListAPIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    pagination_class = None
    model = None

    def get_queryset(self):
        return self.model.objects.filter(is_active=True).order_by("order", "name", "id")


class SectorListView(PublicReferentialView):
    serializer_class = SectorSerializer
    model = Sector

    def get_queryset(self):
        active = Subcategory.objects.filter(is_active=True).order_by("order", "name", "id")
        return super().get_queryset().prefetch_related(
            Prefetch("subcategories", queryset=active, to_attr="active_subcategories")
        )

    @extend_schema(
        tags=["referentials"],
        summary="Secteurs d'activité avec leurs sous-catégories",
        responses=SectorSerializer(many=True),
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


class ServiceCategoryListView(PublicReferentialView):
    serializer_class = ServiceCategorySerializer
    model = ServiceCategory

    @extend_schema(
        tags=["referentials"],
        summary="Catégories de service (prestataires)",
        responses=ServiceCategorySerializer(many=True),
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


class StructureTypeListView(PublicReferentialView):
    serializer_class = StructureTypeSerializer
    model = StructureType

    @extend_schema(
        tags=["referentials"],
        summary="Types de structure",
        responses=StructureTypeSerializer(many=True),
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)
