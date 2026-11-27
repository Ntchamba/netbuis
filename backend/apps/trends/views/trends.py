"""GET /api/trends/?zone= — lit le dernier instantané de la ville (T104).

Connecté et non bloqué. Ne recalcule rien. Jamais de numéro ni d'identifiant de compte
utilisateur. Les commerces sont relus à travers `visible()` : un commerce suspendu depuis le
calcul disparaît tout de suite. Zone inconnue : 400 `invalid` (comme la recherche) ; ville sans
instantané : listes vides.
"""
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import generics, serializers
from rest_framework.response import Response

from apps.accounts.permissions import IsAuthenticatedNotBlocked
from apps.accounts.serializers.otp import ErrorSerializer
from apps.business.models import BusinessProfile
from apps.geo.models import Zone
from apps.trends.models import TrendKind, TrendSnapshot
from apps.trends.serializers.trend import TrendsSerializer
from apps.trends.services.compute_trends import CityResolver
from apps.trends.services.scoring import MAX_ENTRIES


class TrendsQuerySerializer(serializers.Serializer):
    zone = serializers.PrimaryKeyRelatedField(
        queryset=Zone.objects.filter(is_active=True),
        help_text="Identifiant de la ville ou d'un quartier (ramené à sa ville).",
    )


def read_trends(zone) -> dict:
    city_id = CityResolver().city_id(zone.pk)
    snapshot = (
        TrendSnapshot.objects.select_related("zone").filter(zone_id=city_id).first()
        if city_id else None
    )
    if snapshot is None:
        city = Zone.objects.filter(pk=city_id).first() if city_id else None
        return {"zone": {"id": city.pk, "name": city.name} if city else None,
                "computed_at": None, "period_days": None, "products": [], "businesses": []}
    entries = list(snapshot.entries.select_related("product"))
    products = [
        {"id": e.product_id, "name": e.product.name, "rank": e.rank}
        for e in entries if e.kind == TrendKind.PRODUCT and e.product.is_active
    ]
    visible = BusinessProfile.objects.visible().select_related("zone").in_bulk(
        [e.profile_id for e in entries if e.kind == TrendKind.BUSINESS])
    businesses = [
        {"id": e.profile_id, "name": visible[e.profile_id].name, "rank": e.rank,
         "zone": {"id": visible[e.profile_id].zone_id, "name": visible[e.profile_id].zone.name}}
        for e in entries if e.kind == TrendKind.BUSINESS and e.profile_id in visible
    ]
    return {
        "zone": {"id": snapshot.zone_id, "name": snapshot.zone.name},
        "computed_at": snapshot.created_at, "period_days": snapshot.window_days,
        "products": products[:MAX_ENTRIES], "businesses": businesses[:MAX_ENTRIES],
    }


class TrendsView(generics.GenericAPIView):
    permission_classes = [IsAuthenticatedNotBlocked]
    serializer_class = TrendsSerializer
    pagination_class = None

    @extend_schema(
        tags=["trends"], operation_id="trends_list",
        parameters=[OpenApiParameter("zone", int, required=True,
                                     description="Identifiant de la ville ou du quartier.")],
        responses={
            200: TrendsSerializer,
            400: OpenApiResponse(response=ErrorSerializer, description="invalid : zone inconnue."),
            401: OpenApiResponse(response=ErrorSerializer, description="Non connecté."),
            403: OpenApiResponse(response=ErrorSerializer, description="Compte bloqué."),
        },
        description=(
            "Produits les plus recherchés (10 au plus) et commerces actifs les plus contactés "
            "(10 au plus) de la ville sur 7 jours, d'après le dernier calcul. Sans numéro."
        ),
    )
    def get(self, request):
        params = TrendsQuerySerializer(data=request.query_params)
        params.is_valid(raise_exception=True)
        return Response(TrendsSerializer(read_trends(params.validated_data["zone"])).data)
