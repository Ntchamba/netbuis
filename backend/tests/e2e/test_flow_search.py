"""Parcours de recherche (T123) : écrite, par nom (D-27), vocale, suggestions, zones, commerce
masqué. Un seul client connecté fait tout, comme l'application.
"""
import pytest
from django.core.cache import cache

from apps.business.models import BusinessStatus
from apps.geo.models import ZoneLevel
from apps.search.models import SearchLog, SearchMode
from apps.search.tests.helpers import shop
from tests.e2e._aides import COMPLET, administrateur, client_de, compte
from tests.factories.catalog_factory import make_product
from tests.factories.zone_factory import make_maroua_chain, make_zone

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def _cache():
    cache.clear()
    yield
    cache.clear()


def ids(reponse):
    assert reponse.status_code == 200, reponse.content
    return [r["id"] for r in reponse.json()["results"]]


def test_recherche_ecrite_nom_voix_suggestions_zones_et_commerce_masque():
    _, _, _, maroua, harde = make_maroua_chain()
    garoua = make_zone("Garoua", ZoneLevel.VILLE_VILLAGE, maroua.parent)
    riz = shop("Chez Riz Mama", ["Riz parfumé"], zone=harde)
    pharmacie = shop("Pharmacie du Marché", ["Paracétamol"], zone=maroua, subscribed=True)
    lointain = shop("Riz de Garoua", ["Riz local"], zone=garoua)
    make_product("Riz parfumé")
    client = client_de(compte())

    # 1. Recherche écrite par produit : sans casse ni accents, avec une faute légère.
    assert set(ids(client.get("/api/search/", {"q": "RIZ"}))) == {riz.pk, lointain.pk}
    assert riz.pk in ids(client.get("/api/search/", {"q": "parfume"}))
    assert riz.pk in ids(client.get("/api/search/", {"q": "rizz"}))

    # 2. Aucun résultat : liste vide, réponse 200.
    assert ids(client.get("/api/search/", {"q": "hélicoptère"})) == []

    # 3. Par le NOM du commerce (D-27), partiel, accents ignorés, faute légère.
    assert ids(client.get("/api/search/", {"q": "pharmacie"})) == [pharmacie.pk]
    assert ids(client.get("/api/search/", {"q": "MARCHE"})) == [pharmacie.pk]
    assert ids(client.get("/api/search/", {"q": "pharmcie"})) == [pharmacie.pk]

    # 4. Les recherches écrites sont journalisées en mode « écrit ».
    assert SearchLog.objects.filter(mode=SearchMode.TEXT, term="pharmacie").exists()

    # 5. Recherche vocale : la phrase est nettoyée côté serveur et journalisée en « voix ».
    voix = client.post("/api/search/voice/", {"text": "Je cherche du riz s'il vous plaît"},
                       format="json")
    assert voix.status_code == 200 and voix.json()["q"] == "riz"
    assert set(r["id"] for r in voix.json()["results"]) == {riz.pk, lointain.pk}
    assert SearchLog.objects.filter(mode=SearchMode.VOICE, term="riz").exists()
    assert client.post("/api/search/voice/", {}, format="json").status_code == 400

    # 6. Suggestions : le produit du catalogue, puis les termes déjà cherchés.
    sugg = client.get("/api/search/suggestions/", {"q": "ri"})
    assert sugg.status_code == 200
    textes = [s["text"] for s in sugg.json()]
    assert "Riz parfumé" in textes and "riz" in textes

    # 7. Filtres de zone : la ville contient son quartier ; l'autre ville est exclue.
    assert ids(client.get("/api/search/", {"q": "riz", "zone": maroua.pk})) == [riz.pk]
    assert ids(client.get("/api/search/", {"q": "riz", "zone": harde.pk})) == [riz.pk]
    assert ids(client.get("/api/search/", {"q": "riz", "zone": garoua.pk})) == [lointain.pk]
    assert client.get("/api/search/", {"zone": 999999}).status_code == 400

    # 8. Sans mot, la zone est listée avec les abonnés d'abord.
    assert ids(client.get("/api/search/", {"zone": maroua.pk}))[0] == pharmacie.pk

    # 9. Un commerce masqué (bloqué par l'administration) disparaît de la recherche par produit,
    #    par nom et par zone, et sa fiche n'est plus publique.
    admin = client_de(administrateur(COMPLET))
    bloc = admin.post(f"/api/admin/accounts/{riz.owner_id}/block/", {"reason": "Fraude"},
                      format="json")
    assert bloc.status_code == 200
    assert riz.pk not in ids(client.get("/api/search/", {"q": "riz"}))
    assert ids(client.get("/api/search/", {"q": "chez riz mama"})) == []
    assert riz.pk not in ids(client.get("/api/search/", {"zone": harde.pk}))
    assert client.get(f"/api/business/{riz.pk}/").status_code == 404

    # 10. Même chose pour un commerce en attente ou rejeté, créé directement.
    shop("Riz En Attente", ["Riz"], status=BusinessStatus.PENDING)
    shop("Riz Rejeté", ["Riz"], status=BusinessStatus.REJECTED, motif_rejet="x")
    assert ids(client.get("/api/search/", {"q": "riz"})) == [lointain.pk]


def test_recherche_exige_une_connexion_et_refuse_un_compte_bloque():
    from rest_framework.test import APIClient

    from tests.factories.business_factory import make_owner

    assert APIClient().get("/api/search/", {"q": "riz"}).status_code == 401
    user = make_owner()
    client = client_de(user)
    user.is_blocked = True
    user.save()
    assert client.get("/api/search/", {"q": "riz"}).status_code == 403
