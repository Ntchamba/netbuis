"""Suggestions (T041) : GET /api/search/suggestions/?q=."""
import pytest
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.search.models import SearchLog
from tests.factories.business_factory import make_owner
from tests.factories.catalog_factory import make_product

pytestmark = pytest.mark.django_db

URL = "/api/search/suggestions/"


def get(q):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(make_owner())['access']}")
    return client.get(URL, {"q": q})


def test_produits_puis_termes_frequents():
    make_product("Riz parfumé")
    make_product("Fabrication de riz")
    for _ in range(3):
        SearchLog.objects.create(term="riz de maroua", results_count=2)
    SearchLog.objects.create(term="riz sans resultat", results_count=0)
    response = get("RI")
    assert response.status_code == 200
    assert response.json() == [
        {"text": "Riz parfumé", "type": "produit"},
        {"text": "Fabrication de riz", "type": "produit"},
        {"text": "riz de maroua", "type": "recherche"},
    ]


def test_huit_suggestions_au_plus_et_sans_doublon():
    for i in range(10):
        make_product(f"Savon {i}")
    SearchLog.objects.create(term="savon 1", results_count=1)  # déjà proposé comme produit
    result = get("savon").json()
    assert len(result) == 8
    assert len({s["text"].lower() for s in result}) == 8


def test_moins_de_deux_caracteres_ou_vide_donne_rien():
    make_product("Riz")
    assert get("r").json() == []
    assert get("").json() == []


def test_produit_desactive_absent_et_connexion_exigee():
    make_product("Riz inactif", is_active=False)
    assert get("riz").json() == []
    assert APIClient().get(URL, {"q": "riz"}).status_code == 401
