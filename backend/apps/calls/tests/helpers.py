"""Fabriques et appels de test des sessions d'appel (D-25)."""
from itertools import count

from django.contrib.auth.models import Group
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.calls.models import AgentPresence
from tests.factories.user_factory import AdminFactory

SESSIONS = "/api/calls/sessions/"
_admin_numbers = count(1)  # 6 009 xxxx : hors de la plage des comptes de test (6 0000 xxxx)


def make_admin(group=None, **extra):
    """Administrateur (du groupe donné s'il y en a un), sans présence."""
    admin = AdminFactory(phone=f"+2376009{next(_admin_numbers):04d}", **extra)
    if group:
        admin.groups.add(Group.objects.get_or_create(name=group)[0])
    return admin


def client_for(user) -> APIClient:
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    client.user = user
    return client


def post_session(client, business_id=None):
    body = {"business_id": business_id} if business_id else {}
    return client.post(SESSIONS, body, format="json")


def make_agent(group="Validateur", available=True, streams=1, **extra):
    """Administrateur du groupe donné, disponible avec `streams` flux ouverts."""
    agent = make_admin(group, name=extra.pop("name", "Agent"), **extra)
    AgentPresence.objects.create(
        agent=agent, available=available, open_streams=streams, last_seen=timezone.now()
    )
    return agent
