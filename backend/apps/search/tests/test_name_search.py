"""Recherche par le nom du commerce (T041b, décision D-27)."""
import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.business.models import BusinessProfile, BusinessStatus, Offer
from apps.search.services.search_service import (
    WEIGHT_NAME,
    WEIGHT_OFFER,
    WEIGHT_SUBCATEGORY,
    search,
)
from apps.search.tests.helpers import ids, make_subcategory, shop
from tests.factories.business_factory import get_sector, make_owner

pytestmark = pytest.mark.django_db


def test_01_nom_exact():
    cible = shop("Pharmacie du Marché")
    shop("Boutique Autre", ["Riz"])
    assert ids(search("Pharmacie du Marché")) == [cible.pk]


def test_02_nom_partiel_et_sans_casse():
    cible = shop("Pharmacie du Marché")
    assert ids(search("pharmacie")) == [cible.pk]
    assert ids(search("MARCHE")) == [cible.pk]


def test_03_accents_dans_le_nom_et_dans_la_saisie():
    cible = shop("Épicerie Chez Zoé Ndolé")
    assert ids(search("epicerie")) == [cible.pk]
    assert ids(search("NDOLÉ")) == [cible.pk]
    assert ids(search("ndole")) == [cible.pk]


def test_04_faute_de_frappe_legere():
    cible = shop("Pharmacie du Marché")
    assert ids(search("pharmcie")) == [cible.pk]
    assert ids(search("farmacie")) == [cible.pk]


def test_05_nom_sans_rapport_non_trouve():
    shop("Pharmacie du Marché")
    assert ids(search("garage")) == []


def test_06_commerces_non_visibles_jamais_trouves():
    shop("Zeta Attente", status=BusinessStatus.PENDING)
    shop("Zeta Rejet", status=BusinessStatus.REJECTED, motif_rejet="x")
    bloque = shop("Zeta Bloqué")
    bloque.owner.is_blocked = True
    bloque.owner.save()
    supprime = shop("Zeta Supprimé")
    supprime.owner.is_deleted = True
    supprime.owner.save()
    inactif = shop("Zeta Inactif")
    inactif.owner.is_active = False
    inactif.owner.save()
    visible = shop("Zeta Actif")
    assert ids(search("zeta")) == [visible.pk]


def test_07_le_nom_suit_un_changement_de_nom():
    profile = shop("Ancien Nom")
    assert BusinessProfile.objects.get(pk=profile.pk).normalized_name == "ancien nom"
    profile.name = "Nouvelle Étoile"
    profile.save()
    assert BusinessProfile.objects.get(pk=profile.pk).normalized_name == "nouvelle etoile"
    assert ids(search("etoile")) == [profile.pk]
    assert ids(search("ancien")) == []
    profile.name = "Dernier Nom"
    profile.save(update_fields=["name"])
    assert BusinessProfile.objects.get(pk=profile.pk).normalized_name == "dernier nom"


def test_08_ordre_offre_exacte_puis_nom_puis_sous_categorie():
    secteur = get_sector()
    sub = make_subcategory(secteur, code="tomates", name="Tomates")
    par_sous_categorie = shop("Alpha", secteur=secteur)
    par_sous_categorie.sous_categories.add(sub)
    par_nom = shop("Chez Tomates")
    par_offre = shop("Beta", ["Tomates"])
    assert ids(search("tomates")) == [par_offre.pk, par_nom.pk, par_sous_categorie.pk]
    # Un nom exact pèse moins qu'une offre exacte (0,95 contre 1,0), plus qu'une sous-catégorie.
    assert WEIGHT_OFFER > WEIGHT_NAME > WEIGHT_SUBCATEGORY


def test_09_abonne_avant_non_abonne_a_pertinence_egale():
    gratuit = shop("Pharmacie Nord")
    abonne = shop("Pharmacie Sud", subscribed=True)
    assert ids(search("pharmacie")) == [abonne.pk, gratuit.pk]


def test_10_un_resultat_par_compte_nom_et_offre_ensemble():
    profile = shop("Riz Express", ["Riz"])
    assert ids(search("riz")) == [profile.pk]


def test_11_aucun_numero_dans_la_reponse():
    profile = shop("Pharmacie du Marché")
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(make_owner())['access']}")
    response = client.get("/api/search/", {"q": "pharmacie"})
    assert response.status_code == 200
    assert [r["id"] for r in response.json()["results"]] == [profile.pk]
    body = response.content.decode()
    assert profile.phone_anchor not in body and "phone_anchor" not in body


def test_12_nombre_de_requetes_constant():
    def count_queries():
        with CaptureQueriesContext(connection) as queries:
            search("pharmacie").profiles()
        return len(queries)

    shop("Pharmacie 0")
    count_queries()
    base = count_queries()
    for i in range(1, 8):
        profile = shop(f"Pharmacie {i}")
        Offer.objects.create(profile=profile, name=f"Produit {i}")
    assert count_queries() == base


def test_13_index_trigramme_sur_le_nom_normalise():
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT indexdef FROM pg_indexes WHERE indexname = 'business_profile_name_trgm'"
        )
        (definition,) = cursor.fetchone()
    assert "gin" in definition and "normalized_name" in definition
    assert "gin_trgm_ops" in definition


def test_14_requete_sur_le_nom_utilise_l_index_quand_la_table_est_grande():
    shop("Pharmacie du Marché")
    with connection.cursor() as cursor:
        cursor.execute("SET LOCAL enable_seqscan = off")
        cursor.execute(
            "EXPLAIN SELECT id FROM business_businessprofile "
            "WHERE normalized_name %> 'pharmacie'"
        )
        plan = "\n".join(row[0] for row in cursor.fetchall())
    assert "business_profile_name_trgm" in plan, plan
