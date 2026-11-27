"""Signalements (T090) : POST /api/reports/ et son alias POST /api/forum/posts/<id>/report/.

Compte connecté non bloqué. La réponse ne contient jamais l'auteur du signalement.
"""
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.generics import GenericAPIView
from rest_framework.response import Response

from apps.accounts.serializers.otp import ErrorSerializer
from apps.forum.models import ReportTarget
from apps.forum.serializers.report import (
    PostReportSerializer,
    ReportCreateSerializer,
    ReportDoneSerializer,
)
from apps.forum.services import report_service
from apps.forum.views.common import ERR_400, ERR_401, ERR_403, ERR_404, NoStoreMixin

_ERRORS = {
    400: ERR_400, 401: ERR_401, 403: ERR_403, 404: ERR_404,
    409: OpenApiResponse(
        response=ErrorSerializer, description="already_reported : déjà signalé par ce compte"
    ),
}


def _done(report) -> Response:
    target_id = {
        ReportTarget.POST: report.post_id, ReportTarget.COMMENT: report.comment_id,
        ReportTarget.BUSINESS: report.business_id,
    }[report.target_type]
    return Response(
        {"target_type": report.target_type, "target_id": target_id, "reason": report.reason},
        status=status.HTTP_201_CREATED,
    )


class ReportCreateView(NoStoreMixin, GenericAPIView):
    serializer_class = ReportCreateSerializer

    @extend_schema(
        tags=["forum"], operation_id="reports_create", request=ReportCreateSerializer,
        responses={201: ReportDoneSerializer, **_ERRORS},
    )
    def post(self, request):
        serializer = ReportCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        report = report_service.create_report(
            request.user, data["target_type"], data["target_id"], data["reason"]
        )
        return _done(report)


class PostReportView(NoStoreMixin, GenericAPIView):
    serializer_class = PostReportSerializer

    @extend_schema(
        tags=["forum"], operation_id="forum_post_report", request=PostReportSerializer,
        responses={201: ReportDoneSerializer, **_ERRORS},
    )
    def post(self, request, pk):
        serializer = PostReportSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        report = report_service.create_report(
            request.user, ReportTarget.POST, pk, serializer.validated_data["reason"]
        )
        return _done(report)
