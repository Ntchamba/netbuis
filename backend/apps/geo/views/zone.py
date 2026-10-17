"""GET /api/zones/ et GET /api/zones/<id>/ : lecture publique du référentiel (T020).

Seules les zones actives sont visibles, triées par ordre puis par nom. La liste garde la
pagination par défaut du projet (20 par page, 50 au plus avec `page_size`).
Un `parent` qui n'existe pas donne une liste vide (200) ; un `parent` ou un `level`
mal formé donne une erreur 400 claire.
"""
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import generics
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny

from apps.accounts.serializers.otp import ErrorSerializer
from apps.geo.models import Zone, ZoneLevel
from apps.geo.serializers.zone import ZoneDetailSerializer, ZoneSerializer


class ZoneListView(generics.ListAPIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    serializer_class = ZoneSerializer

    def get_queryset(self):
        queryset = Zone.objects.filter(is_active=True).order_by("order", "normalized_name", "id")
        params = self.request.query_params
        level = params.get("level")
        if level:
            if level not in ZoneLevel.values:
                valeurs = ", ".join(ZoneLevel.values)
                raise ValidationError({"level": f"Niveau inconnu. Valeurs : {valeurs}."})
            queryset = queryset.filter(level=level)
        parent = params.get("parent")
        if parent:
            if not parent.isdigit():
                raise ValidationError({"parent": "Doit être un identifiant de zone (entier)."})
            queryset = queryset.filter(parent_id=int(parent))
        return queryset

    @extend_schema(
        tags=["zones"],
        parameters=[
            OpenApiParameter("parent", int, description="Identifiant de la zone parente."),
            OpenApiParameter(
                "level", str, enum=ZoneLevel.values, description="Niveau des zones voulues."
            ),
        ],
        responses={
            200: ZoneSerializer(many=True),
            400: OpenApiResponse(
                response=ErrorSerializer, description="invalid : `level` ou `parent` incorrect"
            ),
        },
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


class ZoneDetailView(generics.RetrieveAPIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    serializer_class = ZoneDetailSerializer

    def get_queryset(self):
        return Zone.objects.filter(is_active=True).select_related("parent")

    @extend_schema(
        tags=["zones"],
        responses={
            200: ZoneDetailSerializer,
            404: OpenApiResponse(
                response=ErrorSerializer, description="not_found : zone inconnue ou désactivée"
            ),
        },
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)
