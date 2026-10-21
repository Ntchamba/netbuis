"""Classement (T040) : abonnés d'abord, puis pertinence, puis proximité ; fautes, synonymes."""
from datetime import timedelta

import pytest
from django.utils import timezone

from apps.business.models import Offer, Subscription, SubscriptionStatus
from apps.search.services.ranking import Hit, rank, relevance_tier, zone_distance
from apps.search.services.search_service import search
from apps.search.tests.helpers import ids, make_zone, shop
from tests.factories.business_factory import make_subscription
from tests.factories.catalog_factory import make_product
from tests.factories.zone_factory import make_maroua_chain

pytestmark = pytest.mark.django_db


# --- Règle de tri pure -----------------------------------------------------------------------

def test_01_abonne_avant_non_abonne_meme_moins_pertinent():
    hits = [Hit(1, 1.0, False, 0), Hit(2, 0.4, True, 5)]
    assert [h.profile_id for h in rank(hits)] == [2, 1]


def test_02_pertinence_avant_proximite():
    hits = [Hit(1, 0.4, False, 0), Hit(2, 1.0, False, 6)]
    assert [h.profile_id for h in rank(hits)] == [2, 1]


def test_03_proximite_departage_une_meme_pertinence():
    hits = [Hit(1, 1.0, False, 4), Hit(2, 1.0, False, 1), Hit(3, 1.0, False, 0)]
    assert [h.profile_id for h in rank(hits)] == [3, 2, 1]


def test_04_ordre_stable_a_egalite_complete():
    hits = [Hit(9, 0.5, False, 1), Hit(3, 0.5, False, 1)]
    assert [h.profile_id for h in rank(hits)] == [3, 9]


def test_05_paliers_de_pertinence():
    assert relevance_tier(1.0) == 4 and relevance_tier(0.99) == 3
    assert relevance_tier(0.3) == 1 and relevance_tier(0.0) == 0


def test_06_distance_entre_zones():
    pays, region, departement, ville, quartier = make_maroua_chain()
    autre = make_zone("Domayo", "quartier", ville)
    parents = {z.pk: z.parent_id for z in (pays, region, departement, ville, quartier, autre)}
    assert zone_distance(quartier.pk, quartier.pk, parents) == 0
    assert zone_distance(quartier.pk, ville.pk, parents) == 1
    assert zone_distance(quartier.pk, autre.pk, parents) == 2
    assert zone_distance(quartier.pk, None, parents) == 0


# --- Classement de bout en bout ----------------------------------------------------------------

def test_07_abonne_actif_d_abord_non_abonne_toujours_liste():
    gratuit = shop("Gratuit", ["Riz"])
    abonne = shop("Abonné", ["Riz"], subscribed=True)
    assert ids(search("riz")) == [abonne.pk, gratuit.pk]


def test_08_abonne_moins_pertinent_reste_devant():
    exact = shop("Exact", ["Riz"])
    approx = shop("Approx", ["Ris blanc"], subscribed=True)
    assert ids(search("riz")) == [approx.pk, exact.pk]


def test_09_abonnement_echu_ou_expire_ne_compte_pas():
    maintenant = timezone.now()
    echu = shop("Échu", ["Riz"])
    make_subscription(echu, start=maintenant - timedelta(days=30),
                      end=maintenant - timedelta(days=1))
    expire = shop("Expiré", ["Riz"])
    make_subscription(expire, status=SubscriptionStatus.EXPIRED)
    actif = shop("Actif", ["Riz"], subscribed=True)
    assert ids(search("riz"))[0] == actif.pk
    assert Subscription.objects.count() == 3
    assert set(ids(search("riz"))) == {echu.pk, expire.pk, actif.pk}


def test_10_pertinence_nom_exact_avant_nom_approchant():
    approx = shop("Approx", ["Ris blanc"])
    exact = shop("Exact", ["Riz parfumé"])
    assert ids(search("riz")) == [exact.pk, approx.pk]


def test_11_proximite_meme_quartier_avant_ville_avant_autre_ville():
    _, _, departement, ville, quartier = make_maroua_chain()
    garoua = make_zone("Garoua", "ville_village", departement)
    loin = shop("Loin", ["Riz"], zone=garoua)
    ville_seule = shop("Ville", ["Riz"], zone=ville)
    proche = shop("Quartier", ["Riz"], zone=quartier)
    assert ids(search("riz", near=quartier)) == [proche.pk, ville_seule.pk, loin.pk]


def test_12_near_ne_filtre_pas_zone_filtre():
    _, _, departement, ville, quartier = make_maroua_chain()
    garoua = make_zone("Garoua", "ville_village", departement)
    a, b = shop("A", ["Riz"], zone=quartier), shop("B", ["Riz"], zone=garoua)
    assert set(ids(search("riz", near=quartier))) == {a.pk, b.pk}
    assert ids(search("riz", zone=quartier)) == [a.pk]


def test_13_faute_de_frappe_classee_apres_le_mot_exact():
    faute = shop("Faute", ["Riz"])
    exact = shop("Exact", ["Ris"])
    assert ids(search("ris")) == [exact.pk, faute.pk]


def test_14_synonyme_trouve_et_classe_par_produit():
    produit = make_product("Riz", synonyms=["riz blanc", "riz local"])
    lie = shop("Lié", [])
    Offer.objects.create(profile=lie, name="Sac 50 kg", catalog_product=produit)
    nomme = shop("Nommé", ["Riz long grain"])
    resultat = ids(search("riz local"))
    assert set(resultat) == {lie.pk, nomme.pk}
    assert resultat[0] == lie.pk  # lié au produit reconnu : meilleur score


def test_15_synonyme_avec_faute_et_accent():
    produit = make_product("Ndolé", synonyms=["ndole bitterleaf"])
    profile = shop("Traiteur", [])
    Offer.objects.create(profile=profile, name="Plat", catalog_product=produit)
    assert ids(search("NDOLÈ")) == [profile.pk]
    assert ids(search("ndolee")) == [profile.pk]


def test_16_abonne_sans_correspondance_n_apparait_pas():
    shop("Abonné hors sujet", ["Chaussures"], subscribed=True)
    gratuit = shop("Gratuit", ["Riz"])
    assert ids(search("riz")) == [gratuit.pk]


def test_17_un_resultat_par_compte_meme_avec_plusieurs_offres():
    profile = shop("Boutique", ["Riz blanc", "Riz parfumé", "Riz local"])
    assert ids(search("riz")) == [profile.pk]


def test_18_liste_sans_terme_abonnes_d_abord_puis_proximite():
    _, _, _, ville, quartier = make_maroua_chain()
    loin = shop("Ville", [], zone=ville)
    proche = shop("Quartier", [], zone=quartier)
    abonne = shop("Abonné ville", [], zone=ville, subscribed=True)
    assert ids(search("", zone=ville, near=quartier)) == [abonne.pk, proche.pk, loin.pk]


def test_19_petits_mots_ignores_dans_la_requete():
    profile = shop("Boutique", ["Huile de palme"])
    assert ids(search("de l'huile")) == [profile.pk]
