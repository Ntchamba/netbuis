"""Demandes de compte business (T071, zone sensible).

- GET  /api/admin/requests/?type=business   : file d'attente paginée (peut_voir_demandes)
- POST /api/admin/requests/<id>/approve/    : passe le profil à `actif` (peut_valider_demande)
- POST /api/admin/requests/<id>/reject/     : exige un motif (peut_valider_demande)
- GET  /api/admin/private-files/<jeton>/    : sert une pièce privée à l'admin du jeton

Le numéro est masqué partout. Une demande déjà traitée répond 409.
"""
from django.http import FileResponse
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework import generics, status
from rest_framework.exceptions import NotFound
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.serializers.otp import ErrorSerializer
from apps.admin_panel.permissions import require
from apps.admin_panel.serializers.business import (
    BusinessRequestSerializer,
    RejectSerializer,
    RequestDecisionSerializer,
)
from apps.admin_panel.services import request_service, rights_service
from apps.business.services import storage_service
from apps.core.exceptions import ApiError

_ERRORS = {
    401: OpenApiResponse(response=ErrorSerializer, description="Jeton absent ou invalide"),
    403: OpenApiResponse(
        response=ErrorSerializer,
        description="Pas administrateur, sans groupe, sans la permission, ou compte bloqué",
    ),
}
_NOT_FOUND = OpenApiResponse(response=ErrorSerializer, description="not_found")
_CONFLICT = OpenApiResponse(
    response=ErrorSerializer, description="already_processed : la demande a déjà été traitée"
)


class InvalidRequestType(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "invalid_type"
    default_detail = "Type de demande inconnu. Valeur acceptée : business."


class InvalidFileLink(ApiError):
    status_code = status.HTTP_403_FORBIDDEN
    default_code = "invalid_link"
    default_detail = "Lien invalide ou expiré."


class BusinessRequestListView(generics.ListAPIView):
    permission_classes = [require(rights_service.VOIR_DEMANDES)]
    serializer_class = BusinessRequestSerializer
    http_method_names = ["get", "options"]

    def get_queryset(self):
        if self.request.query_params.get("type", "business") != "business":
            raise InvalidRequestType()
        return request_service.pending_queryset()

    @extend_schema(
        tags=["admin"], operation_id="admin_requests_list",
        parameters=[OpenApiParameter("type", str, description="Seule valeur : business")],
        description=(
            "File d'attente des comptes business en attente (les plus anciens d'abord). "
            "`cni_url` et `diplome_url` sont des URL temporaires (5 minutes) liées à "
            "l'administrateur qui les reçoit : à ouvrir avec son jeton d'accès via "
            "`GET /api/admin/private-files/<jeton>/`. Le numéro est masqué."
        ),
        responses={200: BusinessRequestSerializer(many=True),
                   400: OpenApiResponse(response=ErrorSerializer, description="invalid_type"),
                   **_ERRORS},
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


class _DecisionView(APIView):
    permission_classes = [require(rights_service.VALIDER_DEMANDE)]
    http_method_names = ["post", "options"]

    def _profile(self, pk):
        profile = request_service.decidable_queryset().filter(pk=pk).first()
        if profile is None:
            raise NotFound()
        return profile

    @staticmethod
    def _answer(profile):
        return Response(RequestDecisionSerializer(profile).data)


class ApproveView(_DecisionView):
    @extend_schema(
        tags=["admin"], operation_id="admin_requests_approve", request=None,
        description=("Passe le compte à `actif` ; pour un prestataire, la CNI est marquée "
                     "vérifiée du même geste. Écrit l'audit `validation_business`."),
        responses={200: RequestDecisionSerializer, 404: _NOT_FOUND, 409: _CONFLICT, **_ERRORS},
    )
    def post(self, request, pk):
        profile = request_service.approve(request.user, self._profile(pk))
        return self._answer(profile)


class RejectView(_DecisionView):
    @extend_schema(
        tags=["admin"], operation_id="admin_requests_reject", request=RejectSerializer,
        description=("Rejette le compte avec un motif obligatoire, que le commerçant lit dans "
                     "`motif_rejet` (`/api/business/me/`). Écrit l'audit `rejet_business`."),
        responses={
            200: RequestDecisionSerializer, 404: _NOT_FOUND, 409: _CONFLICT,
            400: OpenApiResponse(response=ErrorSerializer, description="reason_required"),
            **_ERRORS,
        },
    )
    def post(self, request, pk):
        serializer = RejectSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        reason = serializer.validated_data.get("reason", "")
        profile = request_service.reject(request.user, self._profile(pk), reason)
        return self._answer(profile)


class PrivateFileView(APIView):
    """Sert une pièce privée à l'administrateur désigné par le jeton, et à lui seul."""

    permission_classes = [require(rights_service.VOIR_DEMANDES)]
    http_method_names = ["get", "options"]

    @extend_schema(
        tags=["admin"], operation_id="admin_private_file_retrieve",
        responses={
            (200, "image/*"): OpenApiResponse(description="La pièce (image)"),
            403: OpenApiResponse(
                response=ErrorSerializer,
                description="invalid_link : jeton faux, expiré ou lié à un autre administrateur",
            ),
            401: _ERRORS[401],
        },
    )
    def get(self, request, token):
        storage = storage_service.get_storage()
        try:
            stream = storage.open_private_download(token, admin_id=request.user.pk)
        except storage_service.StorageError:
            raise InvalidFileLink() from None
        header = stream.read(16)
        stream.seek(0)
        content_type = storage_service.detect_content_type(header) or "application/octet-stream"
        response = FileResponse(stream, content_type=content_type)
        response["Cache-Control"] = "no-store, private"
        response["X-Content-Type-Options"] = "nosniff"
        response["Content-Disposition"] = "inline"
        return response
