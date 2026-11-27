"""Parcours complet : recherche → fiche → appel à l'équipe → WhatsApp → historique (T051, T131).

Le numéro du commerçant ne doit apparaître que dans le lien WhatsApp (D-25).
"""
import logging
import secrets

import pytest
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.calls.tests.helpers import make_agent
from apps.search.tests.helpers import shop
from tests.factories.business_factory import make_owner

pytestmark = pytest.mark.django_db


def connected():
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(make_owner())['access']}")
    return client


@pytest.fixture(autouse=True)
def _jitsi(settings):
    settings.JITSI_DOMAIN, settings.JITSI_APP_ID = "jitsi.example.test", "netbuis-test"
    settings.JITSI_JWT_SECRET = secrets.token_urlsafe(48)


def test_search_profile_call_team_history_number_only_in_whatsapp_link(caplog):
    logging.disable(logging.NOTSET)
    caplog.set_level(logging.DEBUG)
    profile = shop("Chez Riz", ["Riz parfumé"])
    phone = profile.phone_anchor
    make_agent()  # un administrateur disponible : l'appel sonne
    client = connected()
    seen = []  # corps de toutes les réponses autres que le lien WhatsApp

    search = client.get("/api/search/", {"q": "riz"})
    assert search.status_code == 200
    (hit,) = search.json()["results"]
    assert hit["id"] == profile.pk
    seen.append(search)

    detail = client.get(f"/api/business/{hit['id']}/")
    assert detail.status_code == 200 and detail.json()["name"] == "Chez Riz"
    seen.append(detail)

    call = client.post("/api/calls/sessions/", {"business_id": hit["id"]}, format="json")
    assert call.status_code == 200 and call.json()["state"] == "ringing"
    assert call["Cache-Control"] == "no-store"
    seen.append(call)
    assert client.post("/api/calls/initiate/", {"business_id": hit["id"], "channel": "call",
                                                "platform": "android"},
                       format="json").status_code == 404
    seen.append(client.post(f"/api/calls/sessions/{call.json()['session_id']}/cancel/"))

    wa = client.post(
        "/api/calls/whatsapp/", {"business_id": hit["id"], "platform": "android"}, format="json",
    )
    assert wa.status_code == 200 and wa.json()["wa_url"].startswith("https://wa.me/237")

    feedback = client.post(f"/api/calls/{wa.json()['call_id']}/feedback/",
                           {"outcome": "answered"}, format="json")
    assert feedback.status_code == 200
    seen.append(feedback)

    history = client.get("/api/calls/history/")
    assert history.status_code == 200
    body = history.json()
    assert body["count"] == 2
    assert {r["type"] for r in body["results"]} == {"call", "whatsapp"}
    assert all(r["business_name"] == "Chez Riz" for r in body["results"])
    seen.append(history)

    digits = phone[-8:]
    for response in seen:
        assert digits not in response.content.decode()
    # la 2e recherche / fiche après l'appel ne le montrent pas non plus
    after = [client.get("/api/search/", {"q": "riz"}), client.get(f"/api/business/{hit['id']}/")]
    for response in after:
        assert digits not in response.content.decode()
    assert digits not in caplog.text
    assert "wa.me" not in caplog.text
