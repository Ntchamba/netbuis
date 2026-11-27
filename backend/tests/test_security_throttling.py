"""T121 — limites de débit. Où se trouve la preuve de chaque limite :

- code SMS, demande / vérification, par IP et par numéro : apps/accounts/tests/test_otp.py
  (test_limite_par_numero, test_limite_par_ip, test_limite_par_ip_sur_la_verification) ;
- connexion administrateur : apps/accounts/tests/test_admin_login.py
  (test_cinq_essais_rates_puis_429_meme_avec_le_bon_mot_de_passe, test_limite_par_ip) ;
- appel : apps/calls/tests/test_rate_limit.py
  (test_sixth_call_in_a_minute_is_429, test_day_limit_50) ;
- envois : apps/business/tests/test_uploads.py (test_limitation_de_debit_par_compte) ;
- commentaires du forum : apps/forum/tests/test_limits.py
  (test_eleventh_comment_in_ten_minutes_is_refused_then_allowed_later) ;
- recherche (écrite, vocale, suggestions) : ci-dessous.
"""
import pytest
from django.conf import settings
from django.core.cache import cache
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.core import throttling
from tests.factories.business_factory import make_owner

pytestmark = pytest.mark.django_db

RATES = settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"]


@pytest.fixture(autouse=True)
def _cache():
    cache.clear()
    yield
    cache.clear()


def connected(user=None):
    client = APIClient()
    client.credentials(
        HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user or make_owner())['access']}"
    )
    return client


def test_les_taux_nommes_existent_et_sont_raisonnables():
    assert set(RATES) >= {"otp", "otp_verify", "call", "uploads", "search", "suggest"}
    assert RATES["search"] == "60/min" and RATES["suggest"] == "120/min"
    assert RATES["otp"] == "10/hour" and RATES["call"] == "5/min"


def test_recherche_ecrite_limitee_par_compte(monkeypatch):
    monkeypatch.setitem(throttling.SearchRateThrottle.THROTTLE_RATES, "search", "3/min")
    client = connected()
    assert [client.get("/api/search/", {"q": "riz"}).status_code for _ in range(3)] == [200] * 3
    blocked = client.get("/api/search/", {"q": "riz"})
    assert blocked.status_code == 429
    assert blocked.json()["code"] == "throttled" and int(blocked["Retry-After"]) > 0
    # Un autre compte a son propre compteur.
    assert connected().get("/api/search/", {"q": "riz"}).status_code == 200


def test_recherche_vocale_partage_la_limite_de_la_recherche_ecrite(monkeypatch):
    monkeypatch.setitem(throttling.SearchRateThrottle.THROTTLE_RATES, "search", "2/min")
    client = connected()
    assert client.get("/api/search/", {"q": "riz"}).status_code == 200
    assert client.post("/api/search/voice/", {"text": "riz"}, format="json").status_code == 200
    assert client.post("/api/search/voice/", {"text": "riz"}, format="json").status_code == 429
    assert client.get("/api/search/", {"q": "riz"}).status_code == 429


def test_suggestions_limitees_par_compte(monkeypatch):
    monkeypatch.setitem(throttling.SuggestRateThrottle.THROTTLE_RATES, "suggest", "2/min")
    client = connected()
    assert client.get("/api/search/suggestions/", {"q": "ri"}).status_code == 200
    assert client.get("/api/search/suggestions/", {"q": "ri"}).status_code == 200
    assert client.get("/api/search/suggestions/", {"q": "ri"}).status_code == 429


def test_usage_normal_non_gene():
    # 20 recherches d'affilée (bien plus qu'un usage humain) passent sous le taux réel.
    client = connected()
    assert all(client.get("/api/search/", {"q": "riz"}).status_code == 200 for _ in range(20))


def test_recherche_sans_jeton_refusee_avant_la_limite():
    assert APIClient().get("/api/search/", {"q": "riz"}).status_code == 401
