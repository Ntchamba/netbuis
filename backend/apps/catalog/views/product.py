"""GET /api/catalog/products/?q= : complétion du catalogue pour le commerçant (T021).

- Public (aucun jeton). 10 résultats au plus, sans pagination (tableau simple).
- Insensible à la casse et aux accents : on compare au nom normalisé.
- Ordre : nom qui commence par q, puis synonyme qui commence par q, puis nom qui contient q,
  puis synonyme qui contient q ; à rang égal, ordre alphabétique. Un produit trouvé par un
  synonyme est renvoyé (une seule fois) sous son nom officiel.
- `q` absent, vide (ou sans lettre/chiffre) : 400. `q` de plus de 100 caractères : 400.
"""
from django.db.models import Case, Exists, IntegerField, OuterRef, Q, Value, When
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import generics
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny

from apps.accounts.serializers.otp import ErrorSerializer
from apps.catalog.models import CatalogProduct, Synonym
from apps.catalog.serializers.product import CatalogProductSerializer
from apps.catalog.services.normalize import MAX_QUERY_LENGTH, normalize_query

MAX_RESULTS = 10


class CatalogProductSearchView(generics.ListAPIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    pagination_class = None
    serializer_class = CatalogProductSerializer

    def get_queryset(self):
        raw = self.request.query_params.get("q", "")
        if len(raw) > MAX_QUERY_LENGTH:
            raise ValidationError({"q": f"{MAX_QUERY_LENGTH} caractères au maximum."})
        term = normalize_query(raw)
        if not term:
            raise ValidationError({"q": "Tapez au moins une lettre ou un chiffre."})
        synonyms = Synonym.objects.filter(product=OuterRef("pk"), is_active=True)
        by_synonym_start = Exists(synonyms.filter(normalized_term__startswith=term))
        by_synonym_contains = Exists(synonyms.filter(normalized_term__contains=term))
        rank = Case(
            When(normalized_name__startswith=term, then=Value(0)),
            When(by_synonym_start, then=Value(1)),
            When(normalized_name__contains=term, then=Value(2)),
            default=Value(3),
            output_field=IntegerField(),
        )
        return (
            CatalogProduct.objects.filter(is_active=True)
            .filter(Q(normalized_name__contains=term) | by_synonym_contains)
            .select_related("category__sector")
            .annotate(rank=rank)
            .order_by("rank", "normalized_name", "id")[:MAX_RESULTS]
        )

    @extend_schema(
        tags=["catalog"],
        summary="Complétion des produits du catalogue",
        parameters=[
            OpenApiParameter(
                "q", str, required=True,
                description="Début ou morceau du nom (ou d'un synonyme), 100 caractères au plus. "
                            "Sans accents ni majuscules.",
            )
        ],
        responses={
            200: CatalogProductSerializer(many=True),
            400: OpenApiResponse(
                response=ErrorSerializer, description="invalid : `q` absent, vide ou trop long"
            ),
        },
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)
