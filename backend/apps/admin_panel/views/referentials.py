"""Référentiels (T074b, zone sensible : Administrateur complet, `peut_gerer_referentiels`).

Pour chacun de : zones, sectors, subcategories, service-categories, structure-types, products,
synonyms :
- GET  /api/admin/referentials/<type>/                   liste paginée (filtres, `is_active`)
- POST /api/admin/referentials/<type>/                   création (audit creation_referentiel)
- GET/PATCH /api/admin/referentials/<type>/<id>/         détail, modification
- POST …/<id>/deactivate/ | reactivate/                  (pas pour les synonymes)
Aucun DELETE : une suppression est une désactivation.
- GET  /api/admin/referentials/free-values/              valeurs libres à examiner
"""
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import generics
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.serializers.otp import ErrorSerializer
from apps.admin_panel.permissions import require
from apps.admin_panel.serializers import referential as s
from apps.admin_panel.services import referential_service as svc
from apps.admin_panel.services import rights_service

PERM = require(rights_service.GERER_REFERENTIELS)

_ERRORS = {
    401: OpenApiResponse(response=ErrorSerializer, description="Jeton absent ou invalide"),
    403: OpenApiResponse(
        response=ErrorSerializer,
        description="Pas administrateur, sans groupe, ou sans peut_gerer_referentiels"),
}
_NOT_FOUND = OpenApiResponse(response=ErrorSerializer, description="not_found")
_BAD = OpenApiResponse(
    response=ErrorSerializer, description="invalid (champ manquant ou incorrect, parent d'un "
    "mauvais niveau, cycle…) avec le détail dans `fields`")
_CONFLICT = OpenApiResponse(
    response=ErrorSerializer,
    description="already_exists / has_active_children / parent_inactive / protected_item / "
                "invalid_state")

# slug -> (sortie, création, modification, filtres documentés)
CONFIG = {
    "zones": (s.AdminZoneSerializer, s.ZoneCreateSerializer, s.ZoneUpdateSerializer,
              [("level", "Niveau (pays, region, departement, arrondissement, ville_village, "
                         "quartier, repere)"),
               ("parent", "Identifiant du parent, ou `root` pour les pays")]),
    "sectors": (s.AdminSectorSerializer, s.ItemCreateSerializer, s.ItemUpdateSerializer, []),
    "subcategories": (s.AdminSubcategorySerializer, s.SubcategoryCreateSerializer,
                      s.ItemUpdateSerializer, [("sector", "Identifiant du secteur")]),
    "service-categories": (s.AdminItemSerializer, s.ItemCreateSerializer,
                           s.ItemUpdateSerializer, []),
    "structure-types": (s.AdminItemSerializer, s.ItemCreateSerializer,
                        s.ItemUpdateSerializer, []),
    "products": (s.AdminProductSerializer, s.ProductCreateSerializer, s.ProductUpdateSerializer,
                 [("category", "Identifiant de la sous-catégorie")]),
    "synonyms": (s.AdminSynonymSerializer, s.SynonymCreateSerializer, s.SynonymUpdateSerializer,
                 [("product", "Identifiant du produit")]),
}


def _params(slug, extra):
    kind = svc.get_kind(slug)
    params = [OpenApiParameter("q", str, description="Recherche sur le nom (sans accents)")]
    if kind.has_active:
        params.append(OpenApiParameter("is_active", bool, description="true ou false"))
    params += [OpenApiParameter(name, str, description=desc) for name, desc in extra]
    return params


def build_views(slug: str) -> dict:
    kind = svc.get_kind(slug)
    out_s, create_s, update_s, extra = CONFIG[slug]
    op = slug.replace("-", "_")

    class ListCreate(generics.ListAPIView):
        permission_classes = [PERM]
        serializer_class = out_s
        http_method_names = ["get", "post", "options"]

        def get_queryset(self):
            return svc.list_queryset(kind, self.request.query_params)

        @extend_schema(
            tags=["admin"], operation_id=f"admin_ref_{op}_list", parameters=_params(slug, extra),
            description=f"Liste paginée ({kind.label}), actifs et désactivés.",
            responses={200: out_s(many=True), **_ERRORS})
        def get(self, request, *args, **kwargs):
            return super().get(request, *args, **kwargs)

        @extend_schema(
            tags=["admin"], operation_id=f"admin_ref_{op}_create", request=create_s,
            description=f"Crée {kind.label} (audit `creation_referentiel`).",
            responses={201: out_s, 400: _BAD, 409: _CONFLICT, **_ERRORS})
        def post(self, request):
            serializer = create_s(data=request.data)
            serializer.is_valid(raise_exception=True)
            obj = svc.create(request.user, kind, serializer.validated_data)
            return Response(out_s(obj).data, status=201)

    class Detail(APIView):
        permission_classes = [PERM]
        http_method_names = ["get", "patch", "options"]

        @extend_schema(
            tags=["admin"], operation_id=f"admin_ref_{op}_detail",
            responses={200: out_s, 404: _NOT_FOUND, **_ERRORS})
        def get(self, request, pk):
            return Response(out_s(svc.get_object(kind, pk)).data)

        @extend_schema(
            tags=["admin"], operation_id=f"admin_ref_{op}_update", request=update_s,
            description=("Modifie les champs envoyés (le niveau et le code stable ne changent "
                         "pas). Audit `modification_referentiel` avec ancienne et nouvelle "
                         "valeur."),
            responses={200: out_s, 400: _BAD, 404: _NOT_FOUND, 409: _CONFLICT, **_ERRORS})
        def patch(self, request, pk):
            serializer = update_s(data=request.data, partial=True)
            serializer.is_valid(raise_exception=True)
            obj = svc.update(request.user, kind, pk, serializer.validated_data)
            return Response(out_s(obj).data)

    views = {"list": ListCreate, "detail": Detail}

    if kind.has_active:
        def toggle(active):
            verb, audit = ("reactivate", "reactivation") if active else (
                "deactivate", "desactivation")

            class Toggle(APIView):
                permission_classes = [PERM]
                http_method_names = ["post", "options"]

                @extend_schema(
                    tags=["admin"], operation_id=f"admin_ref_{op}_{verb}",
                    request=s.ReasonSerializer,
                    description=(
                        f"{'Réactive' if active else 'Désactive'} (jamais de suppression). "
                        f"Audit `{audit}_referentiel`."
                        + ("" if active else " Refusé tant que des éléments rattachés sont "
                           "actifs (409 `has_active_children`) ; la ligne « Autre » est "
                           "protégée (409 `protected_item`).")
                        + (" Refusé si le parent est désactivé (409 `parent_inactive`)."
                           if active else "")),
                    responses={200: out_s, 404: _NOT_FOUND, 409: _CONFLICT, **_ERRORS})
                def post(self, request, pk):
                    serializer = s.ReasonSerializer(data=request.data or {})
                    serializer.is_valid(raise_exception=True)
                    obj = svc.set_active(request.user, kind, pk, active,
                                         serializer.validated_data.get("reason", ""))
                    return Response(out_s(obj).data)

            return Toggle

        views["deactivate"], views["reactivate"] = toggle(False), toggle(True)
    return views


class FreeValuesView(APIView):
    permission_classes = [PERM]
    http_method_names = ["get", "options"]

    @extend_schema(
        tags=["admin"], operation_id="admin_ref_free_values",
        description=(
            "Valeurs libres saisies par les commerçants (« Autre »), regroupées par valeur "
            f"normalisée, triées par fréquence décroissante, {svc.FREE_VALUES_LIMIT} au plus par "
            "champ. Comptes bloqués ou supprimés exclus. Aucun numéro ni donnée personnelle."),
        responses={200: s.FreeValuesSerializer, **_ERRORS})
    def get(self, request):
        return Response(svc.free_values())
