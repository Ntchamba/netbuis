"""Aides communes des tests T074 (aucun secret écrit : mots de passe générés à l'exécution)."""
from django.contrib.auth.models import Group
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from tests.factories.user_factory import AdminFactory, UserFactory

VALIDATEUR, COMPLET = "Validateur", "Administrateur complet"


def admin_in(group, **extra):
    admin = AdminFactory(**extra)
    admin.groups.add(Group.objects.get(name=group))
    return admin


def api_as(user):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    return client


def check_permissions(method, path, body, ok_status):
    """Anonyme 401 ; simple et admin sans groupe 403 ; Validateur 403 ; complet OK."""
    kw = {"format": "json"} if body is not None else {}

    def call(client):
        return getattr(client, method)(path, body, **kw) if body is not None else getattr(
            client, method)(path)

    assert call(APIClient()).status_code == 401
    assert call(api_as(UserFactory())).status_code == 403
    assert call(api_as(AdminFactory())).status_code == 403
    assert call(api_as(admin_in(VALIDATEUR))).status_code == 403
    response = call(api_as(admin_in(COMPLET)))
    assert response.status_code == ok_status, getattr(response, "content", b"")[:300]
    return response
