"""Retour après appel et historique (T051)."""
from datetime import timedelta

import pytest
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.business.models import BusinessStatus
from apps.calls.models import CallFeedback, CallLog
from tests.factories.business_factory import make_owner, make_profile

pytestmark = pytest.mark.django_db

HISTORY = "/api/calls/history/"


def connected(user=None):
    client = APIClient()
    user = user or make_owner()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    client.user = user
    return client


def make_log(caller, profile=None, channel="call"):
    profile = profile or make_profile(status=BusinessStatus.ACTIVE)
    return CallLog.objects.create(caller=caller, profile=profile, channel=channel,
                                  platform="android")


def feedback(client, log, outcome):
    return client.post(f"/api/calls/{log.pk}/feedback/", {"outcome": outcome}, format="json")


@pytest.mark.parametrize("outcome", ["answered", "no_answer", "wrong_number"])
def test_owner_records_feedback(outcome):
    client = connected()
    log = make_log(client.user)
    response = feedback(client, log, outcome)
    assert response.status_code == 200
    assert response.json() == {"call_id": log.pk, "outcome": outcome}
    assert response["Cache-Control"] == "no-store"
    assert CallFeedback.objects.get(call=log).outcome == outcome


def test_feedback_is_modifiable_single_row():
    client = connected()
    log = make_log(client.user)
    feedback(client, log, "no_answer")
    assert feedback(client, log, "answered").status_code == 200
    assert CallFeedback.objects.get(call=log).outcome == "answered"


def test_other_account_cannot_answer_for_a_call():
    log = make_log(make_owner())
    response = feedback(connected(), log, "answered")
    assert response.status_code == 404 and response["Cache-Control"] == "no-store"
    assert not CallFeedback.objects.exists()


def test_feedback_invalid_and_unauthenticated():
    client = connected()
    log = make_log(client.user)
    assert feedback(client, log, "maybe").status_code == 400
    assert feedback(client, make_log(client.user), "").status_code == 400
    assert feedback(connected(), log, "answered").status_code == 404
    assert feedback(APIClient(), log, "answered").status_code == 401
    assert client.post("/api/calls/999999/feedback/", {"outcome": "answered"},
                       format="json").status_code == 404


# --- Historique ---------------------------------------------------------------------------


def test_history_returns_only_my_calls_without_number():
    client = connected()
    profile = make_profile(status=BusinessStatus.ACTIVE, name="Chez Riz")
    mine = make_log(client.user, profile, "whatsapp")
    make_log(make_owner())  # un autre compte
    feedback(client, mine, "answered")
    response = client.get(HISTORY)
    assert response.status_code == 200 and response["Cache-Control"] == "no-store"
    body = response.json()
    assert body["count"] == 1
    (item,) = body["results"]
    assert item["id"] == mine.pk and item["business_name"] == "Chez Riz"
    assert item["zone"] == profile.zone.name and item["type"] == "whatsapp"
    assert item["feedback"] == "answered" and item["date"]
    text = response.content.decode()
    assert profile.phone_anchor not in text and profile.phone_anchor[-8:] not in text
    assert "wa.me" not in text and "phone" not in item


def test_history_paginated_20_newest_first():
    client = connected()
    profile = make_profile(status=BusinessStatus.ACTIVE)
    now = timezone.now()
    for i in range(25):
        log = make_log(client.user, profile)
        CallLog.objects.filter(pk=log.pk).update(created_at=now - timedelta(minutes=i))
    first = client.get(HISTORY).json()
    assert first["count"] == 25 and len(first["results"]) == 20 and first["next"]
    second = client.get(HISTORY, {"page": 2}).json()
    assert len(second["results"]) == 5
    dates = [r["date"] for r in first["results"]]
    assert dates == sorted(dates, reverse=True)


def test_history_requires_login_and_empty_for_new_account():
    assert APIClient().get(HISTORY).status_code == 401
    assert connected().get(HISTORY).json()["results"] == []
