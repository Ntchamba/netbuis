"""Moteur de recherche (T040) : correspondances, tolérance, visibilité, filtres, journal."""
import json

import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext

from apps.accounts.models import User
from apps.business.models import BusinessProfile, BusinessStatus, Offer
from apps.search.models import SearchLog
from apps.search.services.logging import hash_account
from apps.search.services.search_service import search
from apps.search.tests.helpers import ids, make_sector, make_subcategory, make_zone, provider, shop
from apps.search.text.normalize import normalize_search_term
from tests.factories.business_factory import get_sector, make_owner
from tests.factories.catalog_factory import make_product
from tests.factories.zone_factory import make_maroua_chain

pytestmark = pytest.mark.django_db


# --- Normalisation ---------------------------------------------------------------------------

@pytest.mark.parametrize("raw,expected", [
    ("  RIZ  ", "riz"),
    ("Électricité", "electricite"),
    ("huile de palme", "huile palme"),
    ("un plombier", "plombier"),
    ("des Pâtes", "pates"),
    ("de", "de"),
    ("", ""),
    (None, ""),
])
def test_normalisation(raw, expected):
    assert normalize_search_term(raw) == expected


# --- Correspondances par source ----------------------------------------------------------------

def test_offre_trouve_le_compte():
    riz, autre = shop("Chez Riz", ["Riz parfumé 25 kg"]), shop("Chez Huile", ["Huile de palme"])
    assert ids(search("riz")) == [riz.pk]
    assert autre.pk not in ids(search("riz"))


def test_sous_categorie_trouve_le_compte():
    secteur = get_sector()
    sub = make_subcategory(secteur, code="plomberie", name="Plomberie")
    profile = shop("Dépannage", [])
    profile.sous_categories.add(sub)
    assert ids(search("plomberie")) == [profile.pk]


def test_produit_du_catalogue_via_synonyme():
    produit = make_product("Ndolé", synonyms=["tchop"])
    profile = shop("Traiteur", [])
    Offer.objects.create(profile=profile, name="Plat du jour", catalog_product=produit)
    assert ids(search("tchop")) == [profile.pk]


def test_secteur_trouve_le_compte():
    secteur = make_sector(code="pharmacie_sante", name="Pharmacie & Santé")
    profile = shop("Pharma du coin", [], secteur=secteur)
    assert ids(search("pharmacie")) == [profile.pk]


def test_categorie_de_service_trouve_le_prestataire():
    plombier = provider("Dépannage Eau", category=("plombier", "Plombier"))
    provider("Autre", category=("electricien", "Électricien"))
    assert ids(search("plombier")) == [plombier.pk]


def test_secteur_desactive_ne_correspond_plus():
    secteur = make_sector(code="pharmacie_sante", name="Pharmacie & Santé", is_active=False)
    shop("Pharma fermée", [], secteur=secteur)
    assert ids(search("pharmacie")) == []


def test_offre_inactive_ne_correspond_pas():
    profile = shop("Boutique", [])
    Offer.objects.create(profile=profile, name="Riz", is_active=False)
    assert ids(search("riz")) == []


# --- Tolérance -------------------------------------------------------------------------------

@pytest.mark.parametrize("saisie", ["RIZ", "Riz", "riz"])
def test_majuscules_ignorees(saisie):
    profile = shop("Boutique", ["riz"])
    assert ids(search(saisie)) == [profile.pk]


def test_accents_ignores_dans_les_deux_sens():
    profile = shop("Boutique", ["Café moulu"])
    assert ids(search("cafe")) == [profile.pk]
    assert ids(search("CAFÉ")) == [profile.pk]
    autre = shop("Autre", ["Cafe noir"])
    assert set(ids(search("café"))) == {profile.pk, autre.pk}


def test_faute_legere_ris_trouve_riz():
    profile = shop("Boutique", ["Riz parfumé"])
    assert ids(search("ris")) == [profile.pk]


def test_mot_sans_rapport_ne_trouve_rien():
    shop("Boutique", ["Riz parfumé"])
    assert ids(search("tracteur")) == []


# --- Visibilité (jamais visibles) ------------------------------------------------------------

@pytest.mark.parametrize("statut", [BusinessStatus.PENDING, BusinessStatus.REJECTED])
def test_en_attente_et_rejete_jamais_visibles(statut):
    extra = {"motif_rejet": "Photo floue"} if statut == BusinessStatus.REJECTED else {}
    shop("Pas actif", ["Riz"], status=statut, **extra)
    assert ids(search("riz")) == []
    assert ids(search("")) == []


@pytest.mark.parametrize("champ", ["is_blocked", "is_deleted", "is_active"])
def test_bloque_supprime_inactif_jamais_visibles(champ):
    profile = shop("Fiche masquée", ["Riz"])
    visible = shop("Fiche visible", ["Riz"])
    owner = profile.owner
    setattr(owner, champ, champ != "is_active")
    owner.save()
    assert ids(search("riz")) == [visible.pk]
    assert ids(search("")) == [visible.pk]


# --- Filtres ---------------------------------------------------------------------------------

def test_filtre_zone_ville_inclut_ses_quartiers_et_exclut_les_autres():
    _, _, departement, ville, quartier = make_maroua_chain()
    garoua = make_zone("Garoua", "ville_village", departement)
    a, b = shop("A", ["Riz"], zone=quartier), shop("B", ["Riz"], zone=ville)
    c = shop("C", ["Riz"], zone=garoua)
    assert set(ids(search("riz", zone=ville))) == {a.pk, b.pk}
    assert ids(search("riz", zone=garoua)) == [c.pk]
    assert set(ids(search("riz"))) == {a.pk, b.pk, c.pk}


def test_filtre_secteur_par_code_ou_instance():
    alim = get_sector()
    mode = make_sector(code="mode", name="Mode")
    a, b = shop("A", ["Riz"], secteur=alim), shop("B", ["Riz"], secteur=mode)
    assert ids(search("riz", sector="mode")) == [b.pk]
    assert ids(search("riz", sector=alim)) == [a.pk]
    assert ids(search("riz", sector="inconnu")) == []


# --- Aucun téléphone -------------------------------------------------------------------------

def test_le_numero_n_est_jamais_dans_les_resultats():
    profile = shop("Boutique", ["Riz"])
    outcome = search("riz")
    loaded = outcome.profiles()
    assert [p.pk for p in loaded] == [profile.pk]
    deferred = loaded[0].get_deferred_fields()
    assert {"phone_anchor", "cni_photo", "diplome_photo"} <= deferred
    phone = BusinessProfile.objects.get(pk=profile.pk).phone_anchor
    with CaptureQueriesContext(connection) as queries:
        search("riz").profiles()
    assert not any('"phone_anchor"' in q["sql"] for q in queries)
    dump = json.dumps({"hits": [vars(h) for h in outcome.hits], "term": outcome.term})
    assert phone not in dump and profile.owner.phone not in dump


# --- Journal ---------------------------------------------------------------------------------

def test_journal_terme_normalise_zone_nombre_et_hachage():
    _, _, _, ville, _ = make_maroua_chain()
    shop("Boutique", ["Riz"], zone=ville)
    user = make_owner()
    search("  RÎZ ", zone=ville, user=user)
    entry = SearchLog.objects.get()
    assert entry.term == "riz" and entry.zone_id == ville.pk and entry.results_count == 1
    assert entry.mode == "text"
    assert entry.account_hash == hash_account(user)
    assert len(entry.account_hash) == 64
    assert str(user.pk) != entry.account_hash and user.phone not in entry.account_hash


def test_journal_jamais_le_numero_ni_le_compte():
    user = make_owner()
    search("riz", user=user)
    entry = SearchLog.objects.get()
    row = " ".join(str(getattr(entry, f.name)) for f in SearchLog._meta.fields)
    assert user.phone not in row
    assert not any(f.related_model is User for f in SearchLog._meta.fields if f.is_relation)


def test_hachage_stable_distinct_et_vide_sans_compte():
    a, b = make_owner(), make_owner()
    assert hash_account(a) == hash_account(a) != hash_account(b)
    assert hash_account(None) == ""
    search("riz")
    assert SearchLog.objects.get().account_hash == ""


@pytest.mark.parametrize("q", ["", "   ", None, "!!!"])
def test_terme_vide_non_journalise(q):
    shop("Boutique", ["Riz"])
    search(q)
    assert SearchLog.objects.count() == 0


def test_mode_vocal_et_log_desactive():
    search("riz", mode="voice")
    assert SearchLog.objects.get().mode == "voice"
    search("pain", log=False)
    assert SearchLog.objects.count() == 1


def test_liste_de_la_zone_sans_terme():
    _, _, _, ville, _ = make_maroua_chain()
    profile = shop("Boutique", [], zone=ville)
    assert ids(search("", zone=ville)) == [profile.pk]
