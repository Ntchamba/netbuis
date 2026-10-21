"""GET /api/search/suggestions/?q= — au plus 8 suggestions (T041)."""
from drf_spectacular.utils import (
    OpenApiParameter,
    OpenApiResponse,
    extend_schema,
    extend_schema_view,
)
from rest_framework import generics
from rest_framework.response import Response

from apps.accounts.permissions import IsAuthenticatedNotBlocked
from apps.accounts.serializers.otp import ErrorSerializer
from apps.search.serializers.suggestion import SuggestionSerializer
from apps.search.services.suggestions import suggest


@extend_schema_view(get=extend_schema(
    tags=["search"], operation_id="search_suggestions",
    parameters=[OpenApiParameter("q", str, description="Début de mot (2 caractères au moins).")],
    responses={
        200: SuggestionSerializer(many=True),
        401: OpenApiResponse(response=ErrorSerializer, description="Non connecté."),
        403: OpenApiResponse(response=ErrorSerializer, description="Compte bloqué ou supprimé."),
    },
))
class SuggestionsView(generics.GenericAPIView):
    permission_classes = [IsAuthenticatedNotBlocked]
    serializer_class = SuggestionSerializer
    pagination_class = None

    def get(self, request):
        suggestions = suggest(request.query_params.get("q"))
        return Response(SuggestionSerializer(suggestions, many=True).data)
