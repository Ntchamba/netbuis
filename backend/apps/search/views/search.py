"""GET /api/search/ (recherche écrite) et POST /api/search/voice/ (recherche vocale) — T041.

Connecté et non bloqué. Réponse paginée (20 par page). Jamais le numéro de téléphone : il ne
sort que de `POST /api/calls/initiate/`. `q` vide = les commerces de la zone, abonnés d'abord.
"""
from django.db.models import Min
from drf_spectacular.utils import (
    OpenApiParameter,
    OpenApiResponse,
    extend_schema,
    extend_schema_view,
    inline_serializer,
)
from rest_framework import generics, serializers

from apps.accounts.permissions import IsAuthenticatedNotBlocked
from apps.accounts.serializers.otp import ErrorSerializer
from apps.business.models import Offer
from apps.core.pagination import StandardPagination
from apps.core.throttling import SearchRateThrottle
from apps.search.models import SearchMode
from apps.search.serializers.query import SearchQuerySerializer, VoiceQuerySerializer
from apps.search.serializers.result import SearchResultSerializer
from apps.search.services.search_service import search
from apps.search.voice.transcript_cleaner import clean_transcript

_ERRORS = {
    400: OpenApiResponse(response=ErrorSerializer, description="invalid : zone inconnue…"),
    401: OpenApiResponse(response=ErrorSerializer, description="Non connecté."),
    403: OpenApiResponse(response=ErrorSerializer, description="account_blocked / account_deleted"),
    429: OpenApiResponse(response=ErrorSerializer, description="throttled : trop de recherches."),
}


class _Window:
    """Les résultats classés vus comme une liste paginable : seule la page demandée est chargée."""

    def __init__(self, outcome):
        self.outcome = outcome

    def __len__(self):
        return self.outcome.total

    def __getitem__(self, key):
        start, stop = key.start or 0, key.stop
        return self.outcome.profiles(start, None if stop is None else stop - start)


def _prices(profiles) -> dict:
    rows = (
        Offer.objects.filter(
            is_active=True, profile__in=[p.pk for p in profiles], price_fcfa__isnull=False
        )
        .values("profile_id").annotate(low=Min("price_fcfa"))
    )
    return {row["profile_id"]: row["low"] for row in rows}


class _SearchBase(generics.GenericAPIView):
    permission_classes = [IsAuthenticatedNotBlocked]
    throttle_classes = [SearchRateThrottle]  # 60 / minute / compte (réglage `search`)
    pagination_class = StandardPagination
    serializer_class = SearchResultSerializer
    mode = SearchMode.TEXT

    def run(self, request, params: dict, term: str):
        outcome = search(
            term, zone=params["zone"], sector=params["sector"] or None,
            user=request.user, mode=self.mode,
        )
        page = self.paginate_queryset(_Window(outcome))
        context = {**self.get_serializer_context(), "prices": _prices(page)}
        data = SearchResultSerializer(page, many=True, context=context).data
        return self.get_paginated_response(data)


@extend_schema_view(get=extend_schema(
    tags=["search"], operation_id="search_list",
    parameters=[
        OpenApiParameter("q", str, description="Texte cherché ; vide = commerces de la zone."),
        OpenApiParameter("zone", int, description="Identifiant de la zone (ville, quartier…)."),
        OpenApiParameter("sector", str, description="Code stable du secteur."),
    ],
    responses={200: SearchResultSerializer(many=True), **_ERRORS},
))
class SearchView(_SearchBase):
    def get(self, request):
        params = SearchQuerySerializer(data=request.query_params)
        params.is_valid(raise_exception=True)
        return self.run(request, params.validated_data, params.validated_data["q"])


@extend_schema_view(post=extend_schema(
    tags=["search"], operation_id="search_voice",
    request=VoiceQuerySerializer,
    parameters=[OpenApiParameter("page", int, description="Page (20 résultats par page).")],
    responses={
        200: inline_serializer("VoiceSearchPage", {
            "count": serializers.IntegerField(),
            "next": serializers.CharField(allow_null=True),
            "previous": serializers.CharField(allow_null=True),
            "q": serializers.CharField(help_text="Le terme cherché après nettoyage."),
            "results": SearchResultSerializer(many=True),
        }),
        **_ERRORS,
    },
))
class VoiceSearchView(_SearchBase):
    mode = SearchMode.VOICE

    def post(self, request):
        params = VoiceQuerySerializer(data=request.data)
        params.is_valid(raise_exception=True)
        term = clean_transcript(params.validated_data["text"])
        response = self.run(request, params.validated_data, term)
        response.data = {"q": term, **response.data}
        return response
