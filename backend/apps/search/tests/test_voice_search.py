"""Recherche vocale (T041) : nettoyage de la phrase, puis POST /api/search/voice/."""
import pytest
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.search.models import SearchLog, SearchMode
from apps.search.tests.helpers import shop
from apps.search.voice.transcript_cleaner import clean_transcript
from tests.factories.business_factory import make_owner

pytestmark = pytest.mark.django_db

URL = "/api/search/voice/"


@pytest.mark.parametrize("spoken,expected", [
    ("Je cherche du riz", "riz"),
    ("je veux de l'huile de palme", "huile palme"),
    ("Je voudrais un plombier", "plombier"),
    ("Où trouver du ciment ?", "ciment"),
    ("où trouver des tomates fraîches", "tomates fraiches"),
    ("est-ce que vous avez du savon", "savon"),
    ("Est-ce que vous avez des pâtes s'il vous plaît", "pates"),
    ("j'ai besoin d'un électricien", "electricien"),
    ("J'aimerais trouver une couturière", "couturiere"),
    ("Bonjour, je cherche du riz svp", "riz"),
    ("où acheter du poisson fumé merci", "poisson fume"),
    ("riz", "riz"),
    ("  Électricien  ", "electricien"),
    ("", ""),
    ("je cherche", ""),
])
def test_nettoyage_des_phrases_courantes(spoken, expected):
    assert clean_transcript(spoken) == expected


def test_nettoyage_ne_touche_pas_un_mot_qui_contient_une_formule():
    assert clean_transcript("recherche opérationnelle") == "operationnelle"
    assert clean_transcript("jeveuxriz") == "jeveuxriz"


def client_for(user=None):
    client = APIClient()
    client.credentials(
        HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user or make_owner())['access']}"
    )
    return client


def test_voix_cherche_avec_le_texte_nettoye_et_journalise_en_voix():
    riz = shop("Chez Riz", ["Riz parfumé"])
    shop("Chez Huile", ["Huile"])
    response = client_for().post(URL, {"text": "Je cherche du riz s'il vous plaît"}, format="json")
    assert response.status_code == 200
    body = response.json()
    assert body["q"] == "riz" and body["count"] == 1
    assert [r["id"] for r in body["results"]] == [riz.pk]
    log = SearchLog.objects.get()
    assert (log.term, log.mode) == ("riz", SearchMode.VOICE)


def test_voix_sans_texte_utile_liste_la_zone_sans_journal():
    shop("Chez Riz", ["Riz"])
    body = client_for().post(URL, {"text": "je cherche"}, format="json").json()
    assert body["q"] == "" and body["count"] == 1
    assert SearchLog.objects.count() == 0


def test_voix_refuse_sans_texte_ou_sans_connexion():
    assert client_for().post(URL, {}, format="json").status_code == 400
    assert APIClient().post(URL, {"text": "riz"}, format="json").status_code == 401


def test_voix_ne_renvoie_aucun_numero():
    profile = shop("Chez Riz", ["Riz"])
    text = client_for().post(URL, {"text": "je veux du riz"}, format="json").content.decode()
    assert profile.phone_anchor not in text and "+237" not in text
