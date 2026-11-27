"""Carte par zones (T060) : GET /api/map/cities/, /api/map/cities/<id>/areas/,
/api/map/areas/<id>/businesses/. Connecté et non bloqué. Jamais de numéro de téléphone."""
from django.db.models import Min
from django.http import Http404
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import generics
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.permissions import IsAuthenticatedNotBlocked
from apps.accounts.serializers.otp import ErrorSerializer
from apps.business.models import Offer
from apps.core.pagination import StandardPagination
from apps.geo.models import Zone, ZoneLevel
from apps.geo.serializers.map import MapAreasSerializer, MapCitiesSerializer
from apps.geo.services import map as map_service
from apps.search.serializers.result import SearchResultSerializer
from apps.search.services.search_service import search

_ERRORS = {
    401: OpenApiResponse(response=ErrorSerializer, description="Non connecté."),
    403: OpenApiResponse(response=ErrorSerializer, description="account_blocked / account_deleted"),
}
_NOT_FOUND = OpenApiResponse(response=ErrorSerializer, description="not_found")


def _node(zone, explorable=True):
    return None if zone is None else {"id": zone.pk, "name": zone.name, "explorable": explorable}


class MapCitiesView(APIView):
    permission_classes = [IsAuthenticatedNotBlocked]

    @extend_schema(
        tags=["map"], operation_id="map_cities",
        parameters=[OpenApiParameter("q", str, description="Filtre par nom (sans accents/casse).")],
        responses={200: MapCitiesSerializer, **_ERRORS},
    )
    def get(self, request):
        cities, counts = map_service.active_cities(request.query_params.get("q", ""))
        items = [
            {
                "id": c.pk, "name": c.name, "latitude": c.latitude, "longitude": c.longitude,
                "businesses_count": counts[c.pk],
                "region": _node(map_service.ancestor(c, ZoneLevel.REGION)),
                "departement": _node(map_service.ancestor(c, ZoneLevel.DEPARTEMENT)),
            }
            for c in cities
        ]
        data = {"cities": items, "regions": map_service.explorable_hierarchy()}
        return Response(MapCitiesSerializer(data).data)


class MapAreasView(APIView):
    permission_classes = [IsAuthenticatedNotBlocked]

    @extend_schema(
        tags=["map"], operation_id="map_city_areas",
        responses={200: MapAreasSerializer, 404: _NOT_FOUND, **_ERRORS},
    )
    def get(self, request, pk):
        city = Zone.objects.filter(pk=pk).first()
        if city is None or not map_service.city_is_on_map(city):
            raise Http404
        stats, direct = map_service.area_stats(city)
        data = {
            "city": {"id": city.pk, "name": city.name},
            "areas": [
                {"id": a.pk, "name": a.name, "businesses_count": n, "products_count": p}
                for a, n, p in stats
            ],
            "businesses_without_area": direct,
        }
        return Response(MapAreasSerializer(data).data)


class _Window:
    """Résultats classés vus comme une liste paginable (seule la page demandée est chargée)."""

    def __init__(self, outcome):
        self.outcome = outcome

    def __len__(self):
        return self.outcome.total

    def __getitem__(self, key):
        start, stop = key.start or 0, key.stop
        return self.outcome.profiles(start, None if stop is None else stop - start)


class MapAreaBusinessesView(generics.GenericAPIView):
    permission_classes = [IsAuthenticatedNotBlocked]
    pagination_class = StandardPagination
    serializer_class = SearchResultSerializer

    @extend_schema(
        tags=["map"], operation_id="map_area_businesses",
        parameters=[
            OpenApiParameter("page", int, description="Page (20 par page)."),
        ],
        responses={200: SearchResultSerializer(many=True), 404: _NOT_FOUND, **_ERRORS},
    )
    def get(self, request, pk):
        area = Zone.objects.filter(
            pk=pk, level=ZoneLevel.QUARTIER, is_active=True, parent__is_active=True
        ).first()
        if area is None:
            raise Http404
        outcome = search("", zone=area, user=request.user, log=False)
        page = self.paginate_queryset(_Window(outcome))
        prices = dict(
            Offer.objects.filter(
                is_active=True, profile__in=[p.pk for p in page], price_fcfa__isnull=False
            ).values("profile_id").annotate(low=Min("price_fcfa"))
            .values_list("profile_id", "low")
        )
        context = {**self.get_serializer_context(), "prices": prices}
        return self.get_paginated_response(
            SearchResultSerializer(page, many=True, context=context).data
        )

