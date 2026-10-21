"""Parcours complet : recherche → fiche → appel → historique (T051).

Le numéro du commerçant ne doit apparaître que dans la réponse de POST /api/calls/initiate/.
"""
import logging

import pytest
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.search.tests.helpers import shop
from tests.factories.business_factory import make_owner

pytestmark = pytest.mark.django_db


def connected():
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(make_owner())['access']}")
    return client


def test_search_profile_call_history_number_only_in_initiate(caplog):
    logging.disable(logging.NOTSET)
    caplog.set_level(logging.DEBUG)
    profile = shop("Chez Riz", ["Riz parfumé"])
    phone = profile.phone_anchor
    client = connected()
    seen = []  # corps de toutes les réponses autres que initiate

    search = client.get("/api/search/", {"q": "riz"})
    assert search.status_code == 200
    (hit,) = search.json()["results"]
    assert hit["id"] == profile.pk
    seen.append(search)

    detail = client.get(f"/api/business/{hit['id']}/")
    assert detail.status_code == 200 and detail.json()["name"] == "Chez Riz"
    seen.append(detail)

    call = client.post(
        "/api/calls/initiate/",
        {"business_id": hit["id"], "channel": "call", "platform": "android",
         "operator": "orange"},
        format="json",
    )
    assert call.status_code == 200
    assert call.json()["phone"] == phone
    assert call["Cache-Control"] == "no-store"

    wa = client.post(
        "/api/calls/initiate/",
        {"business_id": hit["id"], "channel": "whatsapp", "platform": "android"}, format="json",
    )
    assert wa.status_code == 200 and wa.json()["wa_url"].startswith("https://wa.me/237")

    feedback = client.post(f"/api/calls/{call.json()['call_id']}/feedback/",
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
