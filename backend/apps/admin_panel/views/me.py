"""GET /api/admin/me/ : identité et permissions de l'admin (T070).

Sert au dashboard à masquer les actions interdites ; le serveur refuse de toute façon.
"""
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.serializers.otp import ErrorSerializer
from apps.admin_panel.permissions import IsDashboardAdmin
from apps.admin_panel.serializers.user import AdminMeSerializer
from apps.admin_panel.services import rights_service


class AdminMeView(APIView):
    permission_classes = [IsDashboardAdmin]

    @extend_schema(
        tags=["admin"],
        responses={
            200: AdminMeSerializer,
            401: OpenApiResponse(response=ErrorSerializer, description="Jeton absent ou invalide"),
            403: OpenApiResponse(
                response=ErrorSerializer,
                description="Pas administrateur, sans groupe, ou compte bloqué/supprimé",
            ),
        },
    )
    def get(self, request):
        user = request.user
        data = AdminMeSerializer.build(
            user, rights_service.admin_roles(user), rights_service.admin_permissions(user)
        )
        response = Response(data)
        response["Cache-Control"] = "no-store"
        return response
