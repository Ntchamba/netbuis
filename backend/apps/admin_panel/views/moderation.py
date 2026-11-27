"""Modération du forum (T094, zone sensible) — Administrateur complet seulement
(`peut_moderer_contenu`) : le Validateur ne modère pas.

- GET  /api/admin/reports/                              file des signalements (paginée)
- POST /api/admin/reports/<post|comment>/<id>/hide|restore|delete/   (delete : motif obligatoire)
- GET/POST /api/admin/forbidden-words/, DELETE /api/admin/forbidden-words/<id>/   mots interdits
Toutes les réponses sont `no-store`. Aucun numéro en clair, jamais l'identité des signalants.
"""
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.generics import GenericAPIView
from rest_framework.response import Response

from apps.accounts.serializers.otp import ErrorSerializer
from apps.admin_panel.permissions import require
from apps.admin_panel.serializers.moderation import (
    ForbiddenWordCreateSerializer,
    ForbiddenWordSerializer,
    ModerationActionSerializer,
    ReportRowSerializer,
)
from apps.admin_panel.services import moderation_service as service
from apps.admin_panel.services import rights_service
from apps.forum.models import ForbiddenWord

_PERM = [require(rights_service.MODERER_CONTENU)]
_ERR = {
    401: OpenApiResponse(response=ErrorSerializer, description="Jeton absent ou invalide"),
    403: OpenApiResponse(response=ErrorSerializer,
                         description="Pas Administrateur complet (le Validateur ne modère pas)"),
}
_NOT_FOUND = OpenApiResponse(response=ErrorSerializer, description="not_found")


class _NoStore:
    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = "no-store"
        return response


class ReportListView(_NoStore, GenericAPIView):
    permission_classes = _PERM
    serializer_class = ReportRowSerializer
    http_method_names = ["get", "options"]

    @extend_schema(
        tags=["admin"], operation_id="admin_reports_list",
        parameters=[
            OpenApiParameter("status", str, enum=list(service.STATUS_FILTERS),
                             description="Statut du contenu signalé (commerce : statut du compte)"),
            OpenApiParameter("type", str, enum=list(service.TYPE_FILTERS),
                             description="Type de cible"),
        ],
        description=("Une ligne par contenu signalé, le plus récemment signalé d'abord, paginée : "
                     "motifs avec compteur, nombre de signalants distincts, statut, aperçu "
                     "(numéros masqués). Jamais l'identité des signalants."),
        responses={200: ReportRowSerializer(many=True),
                   400: OpenApiResponse(response=ErrorSerializer, description="invalid_filter"),
                   **_ERR},
    )
    def get(self, request):
        groups = service.queue(request.query_params.get("status"),
                               request.query_params.get("type"))
        page = self.paginate_queryset(groups)
        rows = service.build_rows(page)
        return self.get_paginated_response(ReportRowSerializer(rows, many=True).data)


class _ModerationView(_NoStore, GenericAPIView):
    permission_classes = _PERM
    serializer_class = ReportRowSerializer
    http_method_names = ["post", "options"]
    action: str

    def post(self, request, target_type, pk):
        body = ModerationActionSerializer(data=request.data if request.data else {})
        body.is_valid(raise_exception=True)
        row = service.moderate(request.user, self.action, target_type, pk,
                               body.validated_data.get("reason", ""))
        return Response(ReportRowSerializer(row).data)


def _schema(operation_id, text):
    return extend_schema(
        tags=["admin"], operation_id=operation_id, request=ModerationActionSerializer,
        description=text,
        responses={
            200: ReportRowSerializer,
            400: OpenApiResponse(
                response=ErrorSerializer,
                description="reason_required (supprimer sans motif, rien n'est écrit) ; "
                            "unsupported_target (commerce) ; invalid"),
            404: _NOT_FOUND,
            409: OpenApiResponse(response=ErrorSerializer, description="invalid_state"),
            **_ERR,
        },
    )


class HideView(_ModerationView):
    action = service.HIDE

    @_schema("admin_reports_hide",
             "Masque une publication ou un commentaire signalé (actif -> masque). Audit "
             "`moderation_contenu`. Le contenu disparaît du fil, du détail et des commentaires ; "
             "son auteur le voit dans `/api/forum/mine/` avec le statut `masque`.")
    def post(self, request, target_type, pk):
        return super().post(request, target_type, pk)


class RestoreView(_ModerationView):
    action = service.RESTORE

    @_schema("admin_reports_restore",
             "Restaure un contenu masqué (masque -> actif). Les signalements restent mais ne "
             "comptent plus pour le masquage automatique : il faut 3 NOUVEAUX signalants "
             "distincts. Audit `moderation_contenu`.")
    def post(self, request, target_type, pk):
        return super().post(request, target_type, pk)


class DeleteView(_ModerationView):
    action = service.DELETE

    @_schema("admin_reports_delete",
             "Suppression DOUCE (actif ou masque -> supprime), motif OBLIGATOIRE dans le corps. "
             "Audit `moderation_contenu` dans la même transaction.")
    def post(self, request, target_type, pk):
        return super().post(request, target_type, pk)


class ForbiddenWordListCreateView(_NoStore, GenericAPIView):
    permission_classes = _PERM
    serializer_class = ForbiddenWordSerializer
    http_method_names = ["get", "post", "options"]

    @extend_schema(
        tags=["admin"], operation_id="admin_forbidden_words_list",
        description="Mots interdits du forum (normalisés), par ordre alphabétique, paginés.",
        responses={200: ForbiddenWordSerializer(many=True), **_ERR},
    )
    def get(self, request):
        page = self.paginate_queryset(ForbiddenWord.objects.all())
        return self.get_paginated_response(ForbiddenWordSerializer(page, many=True).data)

    @extend_schema(
        tags=["admin"], operation_id="admin_forbidden_words_create",
        request=ForbiddenWordCreateSerializer,
        description=("Ajoute un mot interdit (stocké sans accents ni majuscules ; comparaison "
                     "par mots entiers). Audit `moderation_contenu`."),
        responses={201: ForbiddenWordSerializer,
                   400: OpenApiResponse(response=ErrorSerializer, description="invalid"),
                   409: OpenApiResponse(response=ErrorSerializer, description="word_exists"),
                   **_ERR},
    )
    def post(self, request):
        body = ForbiddenWordCreateSerializer(data=request.data)
        body.is_valid(raise_exception=True)
        word = service.add_word(request.user, body.validated_data["word"])
        return Response(ForbiddenWordSerializer(word).data, status=status.HTTP_201_CREATED)


class ForbiddenWordDetailView(_NoStore, GenericAPIView):
    permission_classes = _PERM
    serializer_class = ForbiddenWordSerializer
    http_method_names = ["delete", "options"]

    @extend_schema(
        tags=["admin"], operation_id="admin_forbidden_words_delete",
        description="Retire un mot interdit. Audit `moderation_contenu`.",
        responses={204: None, 404: _NOT_FOUND, **_ERR},
    )
    def delete(self, request, pk):
        service.remove_word(request.user, pk)
        return Response(status=status.HTTP_204_NO_CONTENT)
