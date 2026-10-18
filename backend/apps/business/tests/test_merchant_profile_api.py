"""Compte business, API du propriétaire (T026) : POST /api/business/, GET/PATCH
/api/business/me/. Numéros de test 6 00 00 00 XX / générés par les fabriques."""
import json
import logging
from datetime import timedelta

import pytest
from django.core.cache import cache
from django.urls import resolve
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.business.models import BusinessProfile, BusinessStatus
from apps.business.views.merchant_profile import MerchantProfileView
from apps.catalog.models import Subcategory
from apps.core.models.platform_setting import PlatformSetting
from apps.core.services.settings_service import invalidate_setting
from apps.geo.models import ZoneLevel
from tests.factories.business_factory import (
    get_or_make_zone,
    get_sector,
    get_service_category,
    get_structure_type,
    make_owner,
    make_profile,
    make_subscription,
)
from tests.factories.catalog_factory import make_sector, make_subcategory
from tests.factories.storage_factory import make_stored_file

pytestmark = pytest.mark.django_db

URL = "/api/business/"
ME = "/api/business/me/"
PHONE = "+237677123456"
CNI = "@cni_photo"  # remplacé par une vraie clé de stockage du compte connecté (voir `with_files`)


@pytest.fixture(autouse=True)
def _clear_cache():
    cache.clear()
    yield
    cache.clear()


def connected(user):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    client.user = user
    return client


def with_files(client, body):
    """Remplace chaque valeur « @kind » par la clé d'un petit fichier réel déposé (stockage de
    test) pour le compte connecté : T027 n'accepte que des clés existantes et à soi."""
    user = getattr(client, "user", None)
    if user is None:  # client anonyme : rien à déposer
        return body
    return {
        name: make_stored_file(user, value[1:])
        if isinstance(value, str) and value.startswith("@") else value
        for name, value in body.items()
    }


@pytest.fixture
def owner():
    return make_owner()


@pytest.fixture
def client(owner):
    return connected(owner)


def payload(type_compte="boutique", **extra) -> dict:
    """Corps JSON valide pour `type_compte` (référentiels par identifiant)."""
    body = {
        "type_compte": type_compte,
        "name": "Boutique de démonstration",
        "zone": get_or_make_zone().pk,
        "photo": "@photo",
        "representant_nom": "Personne de démonstration",
        "representant_photo": "@representant_photo",
        "phone_anchor": PHONE,
    }
    if type_compte in ("boutique", "entreprise", "particulier_vendeur"):
        body["secteur"] = get_sector().pk
    if type_compte == "entreprise":
        body["forme_juridique"] = "sarl"
    if type_compte == "prestataire_service":
        body["categorie_service"] = get_service_category().pk
        body["cni_photo"] = CNI
    if type_compte == "structure":
        body["structure_type"] = get_structure_type().pk
        body.update(cuisine="camerounaise", livraison=True)
    body.update(extra)
    return body


def post(client, body):
    return client.post(URL, with_files(client, body), format="json")


def patch(client, body):
    return client.patch(ME, with_files(client, body), format="json")


def fields_of(response):
    assert response.status_code == 400, response.content
    assert response.json()["code"] == "invalid"
    return response.json()["fields"]


def active_profile(owner=None, type_compte="boutique", **extra):
    return make_profile(
        type_compte, owner=owner or make_owner(), status=BusinessStatus.ACTIVE, **extra
    )


def subs_of(sector, n):
    return [make_subcategory(sector, f"s{i}", f"S{i}").pk for i in range(n)]


# --- 1. Création : un cas valide par type ------------------------------------------------


@pytest.mark.parametrize(
    "type_compte",
    ["boutique", "entreprise", "particulier_vendeur", "prestataire_service", "structure"],
)
def test_creation_valide_par_type(client, owner, type_compte):
    response = post(client, payload(type_compte))
    assert response.status_code == 201, response.content
    body = response.json()
    assert body["status"] == "en_attente_validation"
    assert body["type_compte"] == type_compte
    assert body["phone_masked"] == "+237 6•• •• •• 56"
    profile = BusinessProfile.objects.get(owner=owner)
    assert profile.pk == body["id"]
    assert profile.status == BusinessStatus.PENDING
    assert profile.phone_anchor == PHONE


def test_creation_valide_de_chaque_structure_et_sous_categories(client):
    # Supermarché, hôtel, centre de santé : un cas valide chacun.
    cas = [
        ("supermarche", {"rayons": ["boissons", "produits_frais"]}),
        ("hotel", {"standing": "confort", "nombre_chambres": 12, "equipements": ["wifi"]}),
        ("sante", {"specialites": ["pediatrie"]}),  # numéro d'agrément facultatif
    ]
    for code, details in cas:
        user = make_owner()
        body = payload("structure", structure_type=get_structure_type(code, code).pk)
        for key in ("cuisine", "livraison"):
            body.pop(key)
        body.update(details)
        assert post(connected(user), body).status_code == 201, code


def test_creation_boutique_avec_sous_categories(client, owner):
    subs = subs_of(get_sector(), 3)
    response = post(client, payload("boutique", sous_categories=subs))
    assert response.status_code == 201
    assert sorted(response.json()["sous_categories"]) == sorted(subs)
    assert BusinessProfile.objects.get(owner=owner).sous_categories.count() == 3


# --- 2. Un cas invalide par type ---------------------------------------------------------


@pytest.mark.parametrize(
    ("type_compte", "retire", "champ"),
    [
        ("boutique", "secteur", "secteur"),
        ("entreprise", "forme_juridique", "forme_juridique"),
        ("particulier_vendeur", "secteur", "secteur"),
        ("prestataire_service", "cni_photo", "cni_photo"),
        ("prestataire_service", "categorie_service", "categorie_service"),
        ("structure", "structure_type", "structure_type"),
    ],
)
def test_creation_invalide_par_type(client, owner, type_compte, retire, champ):
    body = payload(type_compte)
    body.pop(retire)
    errors = fields_of(post(client, body))
    assert champ in errors
    assert not BusinessProfile.objects.filter(owner=owner).exists()


@pytest.mark.parametrize("retire", ["photo", "representant_nom", "representant_photo",
                                    "phone_anchor", "name", "zone", "type_compte"])
def test_champs_communs_obligatoires(client, retire):
    body = payload()
    body.pop(retire)
    assert retire in fields_of(post(client, body))


def test_champ_d_un_autre_type_refuse(client):
    errors = fields_of(post(client, payload("boutique", forme_juridique="sarl")))
    assert "forme_juridique" in errors
    errors = fields_of(post(client, payload("boutique", cni_photo=CNI)))
    assert "cni_photo" in errors


@pytest.mark.parametrize(
    ("code", "details", "manque"),
    [
        ("supermarche", {}, "rayons"),
        ("restaurant", {"livraison": True}, "cuisine"),
        ("restaurant", {"cuisine": "fast_food"}, "livraison"),
        ("hotel", {"nombre_chambres": 5}, "standing"),
        ("sante", {"numero_agrement": "AG-1"}, "specialites"),
    ],
)
def test_details_de_structure_obligatoires(client, code, details, manque):
    body = payload("structure", structure_type=get_structure_type(code, code).pk)
    for key in ("cuisine", "livraison"):
        body.pop(key)
    body.update(details)
    assert manque in fields_of(post(client, body))


def test_detail_d_un_autre_type_de_structure_refuse(client):
    body = payload("structure", rayons=["boissons"])  # restaurant avec un rayon
    assert "rayons" in fields_of(post(client, body))


def test_valeurs_inconnues_refusees(client):
    assert "cuisine" in fields_of(post(client, payload("structure", cuisine="martienne")))
    assert "secteur" in fields_of(post(client, payload(secteur=999999)))
    assert "type_compte" in fields_of(post(client, payload(type_compte="roi")))
    assert "sous_categories" in fields_of(post(client, payload(sous_categories=[999999])))


def test_sous_categorie_d_un_autre_secteur_annule_tout(client, owner):
    autre = make_subcategory(make_sector("immobilier", "Immobilier"), "terrain", "Terrain")
    errors = fields_of(post(client, payload(sous_categories=[autre.pk])))
    assert "sous_categories" in errors
    assert not BusinessProfile.objects.filter(owner=owner).exists()


def test_sous_categories_interdites_au_prestataire(client):
    sub = subs_of(get_sector(), 1)
    assert "sous_categories" in fields_of(post(client, payload("prestataire_service",
                                                               sous_categories=sub)))


# --- Accès et permissions ----------------------------------------------------------------


def test_anonyme_refuse():
    assert post(APIClient(), payload()).status_code == 401
    assert APIClient().get(ME).status_code == 401
    assert APIClient().patch(ME, {}, format="json").status_code == 401


def test_second_compte_business_refuse_409(client, owner):
    assert post(client, payload()).status_code == 201
    response = post(client, payload(name="Autre nom"))
    assert response.status_code == 409
    assert response.json()["code"] == "business_exists"
    assert BusinessProfile.objects.filter(owner=owner).count() == 1


def test_compte_sans_profil_recoit_404(client):
    for response in (client.get(ME), patch(client, {"description": "x"})):
        assert response.status_code == 404
        assert response.json()["code"] == "no_business"


def test_un_compte_ne_voit_que_le_sien(client, owner):
    autre = make_profile(name="Pas à moi")
    assert client.get(ME).status_code == 404  # le profil d'un autre n'est pas le sien
    mine = make_profile(owner=owner, name="À moi")
    assert client.get(ME).json()["id"] == mine.pk != autre.pk


@pytest.mark.parametrize("flag", ["is_blocked", "is_deleted"])
def test_compte_bloque_ou_supprime_refuse(flag):
    user = make_owner()
    client = connected(user)
    setattr(user, flag, True)
    user.save()
    assert post(client, payload()).status_code == 403
    assert client.get(ME).status_code == 403


def test_pas_de_delete_ni_put(client, owner):
    make_profile(owner=owner)
    assert client.delete(ME).status_code == 405
    assert client.put(ME, payload(), format="json").status_code == 405
    assert client.get(URL).status_code == 405


def test_compte_supprime_perd_l_acces_a_son_profil(client, owner):
    make_profile(owner=owner)
    assert client.get(ME).status_code == 200
    assert client.delete("/api/me/").status_code == 204
    response = client.get(ME)
    assert response.status_code == 403
    assert response.json()["code"] == "account_deleted"


def test_me_n_est_pas_capture_par_une_route_id():
    assert resolve(ME).func.view_class is MerchantProfileView


# --- Champs protégés ---------------------------------------------------------------------


def test_le_client_ne_peut_pas_imposer_les_champs_serveur(client, owner):
    other = make_owner()
    body = payload(
        status="actif", owner=other.pk, motif_rejet="x", cni_verifiee=True,
        calls_count=50, views_count=50,
    )
    response = post(client, body)
    assert response.status_code == 201
    profile = BusinessProfile.objects.get(pk=response.json()["id"])
    assert profile.owner == owner
    assert profile.status == BusinessStatus.PENDING
    assert (profile.motif_rejet, profile.cni_verifiee) == ("", False)
    assert (profile.calls_count, profile.views_count) == (0, 0)


def test_le_numero_et_la_cni_ne_sortent_jamais(client, owner):
    created = post(client, payload("prestataire_service", phone_anchor="677 12 34 56"))
    assert created.status_code == 201
    profile = BusinessProfile.objects.get(owner=owner)
    assert profile.phone_anchor == PHONE  # normalisé
    stored_cni = profile.cni_photo
    assert stored_cni.startswith(f"u{owner.pk}/cni_photo/")
    for response in (created, client.get(ME), patch(client, {"description": "Bonjour"})):
        text = response.content.decode()
        assert "phone_anchor" not in response.json()
        assert "cni_photo" not in response.json()
        assert "677123456" not in text.replace(" ", "")
        assert stored_cni not in text
        assert response.json()["has_cni"] is True
        assert response.json()["phone_masked"] == "+237 6•• •• •• 56"


def test_numero_invalide_refuse_sans_le_repeter(client):
    errors = fields_of(post(client, payload(phone_anchor="12345XYZ")))
    assert "phone_anchor" in errors
    assert "12345XYZ" not in json.dumps(errors)
    assert "phone_anchor" in fields_of(post(client, payload(phone_anchor="")))


def test_aucun_journal_ne_contient_le_numero(client, caplog):
    caplog.set_level(logging.DEBUG)
    body = with_files(client, payload("prestataire_service"))
    post(client, body)
    post(client, payload("prestataire_service", cni_photo="../x"))
    assert "677123456" not in caplog.text
    assert body["cni_photo"] not in caplog.text


@pytest.mark.parametrize("key", ["../x.jpg", "a/../b.jpg", "/etc/passwd", "a//b.jpg", "./a",
                                 "http://exemple.cm/a.jpg", "a\\b.jpg"])
def test_cles_de_stockage_invalides(client, key):
    for champ in ("photo", "representant_photo", "diplome_photo"):
        errors = fields_of(post(client, payload(**{champ: key})))
        assert champ in errors
        assert key not in json.dumps(errors)
    assert "cni_photo" in fields_of(post(client, payload("prestataire_service", cni_photo=key)))


def test_cle_de_stockage_trop_longue(client):
    assert "photo" in fields_of(post(client, payload(photo="a/" + "b" * 260)))


# --- 5. Lieu : région seule refusée ------------------------------------------------------


@pytest.mark.parametrize("level", [ZoneLevel.PAYS, ZoneLevel.REGION, ZoneLevel.DEPARTEMENT])
def test_zone_trop_haute_refusee_a_la_creation(client, owner, level):
    zone = get_or_make_zone(level)
    assert "zone" in fields_of(post(client, payload(zone=zone.pk)))
    assert not BusinessProfile.objects.filter(owner=owner).exists()


def test_zone_trop_haute_refusee_a_la_modification(client, owner):
    profile = make_profile(owner=owner)
    zone = get_or_make_zone(ZoneLevel.REGION)
    assert "zone" in fields_of(patch(client, {"zone": zone.pk}))
    profile.refresh_from_db()
    assert profile.zone.level == ZoneLevel.QUARTIER


def test_ville_acceptee(client):
    ville = get_or_make_zone(ZoneLevel.VILLE_VILLAGE)
    assert post(client, payload(zone=ville.pk)).status_code == 201


# --- 3. Plafond de 3 ---------------------------------------------------------------------


def test_trois_sous_categories_acceptees_la_quatrieme_refusee(client, owner):
    secteur = get_sector()
    subs = subs_of(secteur, 4)
    assert post(client, payload(sous_categories=subs[:3])).status_code == 201
    profile = BusinessProfile.objects.get(owner=owner)
    response = patch(client, {"sous_categories": subs})
    assert response.status_code == 400
    body = response.json()
    assert body["code"] == "SUBSCRIPTION_REQUIRED"
    assert "3 sous-catégories" in body["message"]
    assert profile.sous_categories.count() == 3


def test_quatre_sous_categories_refusees_a_la_creation(client, owner):
    response = post(client, payload(sous_categories=subs_of(get_sector(), 4)))
    assert response.status_code == 400
    assert response.json()["code"] == "SUBSCRIPTION_REQUIRED"
    assert not BusinessProfile.objects.filter(owner=owner).exists()


def test_abonne_actif_non_plafonne(client, owner):
    profile = make_profile(owner=owner)
    make_subscription(profile)
    subs = subs_of(get_sector(), 5)
    response = patch(client, {"sous_categories": subs})
    assert response.status_code == 200
    assert len(response.json()["sous_categories"]) == 5


def test_abonnement_echu_refuse_mais_ne_supprime_rien(client, owner):
    profile = make_profile(owner=owner)
    now = timezone.now()
    make_subscription(profile, start=now - timedelta(days=40), end=now - timedelta(days=10))
    subs = subs_of(get_sector(), 5)
    profile.sous_categories.set(subs)  # posées du temps de l'abonnement
    assert patch(client, {"sous_categories": subs[:4]}).status_code == 200  # retrait d'un seul
    assert patch(client, {"description": "Nouvelle description"}).status_code == 200
    profile.refresh_from_db()
    assert profile.sous_categories.count() == 4
    assert profile.description == "Nouvelle description"
    # Ajouter un 5e élément qu'on n'avait pas retiré est un ajout : refusé.
    response = patch(client, {"sous_categories": subs})
    assert response.json()["code"] == "SUBSCRIPTION_REQUIRED"
    # Renvoyer ses éléments actuels n'est pas un ajout.
    assert patch(client, {"sous_categories": subs[:4]}).status_code == 200
    assert profile.sous_categories.count() == 4


def test_plafond_lu_dans_les_reglages(client):
    PlatformSetting.objects.create(key="plafond_sous_categories_non_abonne", value=2)
    invalidate_setting("plafond_sous_categories_non_abonne")
    secteur = get_sector()
    response = post(client, payload(sous_categories=subs_of(secteur, 3)))
    assert response.json()["code"] == "SUBSCRIPTION_REQUIRED"
    assert "2 sous-catégories" in response.json()["message"]
    assert post(client, payload(sous_categories=Subcategory.objects.values_list("pk", flat=True)[:2]
                                )).status_code == 201


def test_plafond_des_rayons(client, owner):
    supermarche = get_structure_type("supermarche", "Supermarché").pk
    base = payload("structure", structure_type=supermarche)
    for key in ("cuisine", "livraison"):
        base.pop(key)
    tous = ["boissons", "produits_frais", "alimentation_generale", "hygiene_beaute"]
    response = post(client, {**base, "rayons": tous})
    assert response.status_code == 400
    assert response.json()["code"] == "SUBSCRIPTION_REQUIRED"
    assert "3 rayons" in response.json()["message"]
    assert post(client, {**base, "rayons": tous[:3]}).status_code == 201
    make_subscription(BusinessProfile.objects.get(owner=owner))
    assert patch(client, {"rayons": tous}).status_code == 200


def test_plafond_des_specialites(client):
    sante = get_structure_type("sante", "Centre de santé").pk
    base = payload("structure", structure_type=sante)
    for key in ("cuisine", "livraison"):
        base.pop(key)
    tous = ["pediatrie", "gynecologie", "dentisterie", "laboratoire"]
    response = post(client, {**base, "specialites": tous})
    assert response.json()["code"] == "SUBSCRIPTION_REQUIRED"
    assert "3 spécialités" in response.json()["message"]
    assert post(client, {**base, "specialites": tous[:3]}).status_code == 201


# --- 4. Règle D-08 -----------------------------------------------------------------------


def test_d08_description_et_photos_sans_nouvelle_validation(client, owner):
    profile = active_profile(owner)
    response = patch(client, {
        "description": "Nouvelle description", "photo": "@photo",
        "representant_photo": "@representant_photo", "repere": "Près du marché",
        "whatsapp_available": False, "description_activite": "Fruits frais",
    })
    assert response.status_code == 200, response.content
    assert response.json()["status"] == "actif"
    profile.refresh_from_db()
    assert profile.status == BusinessStatus.ACTIVE
    assert profile.description == "Nouvelle description"
    assert BusinessProfile.objects.visible().filter(pk=profile.pk).exists()


def test_d08_valeur_identique_ne_change_rien(client, owner):
    profile = active_profile(owner)
    response = patch(client, {
        "name": profile.name, "type_compte": profile.type_compte, "zone": profile.zone_id,
        "phone_anchor": profile.phone_anchor[4:],  # même numéro, autre écriture
    })
    assert response.status_code == 200
    assert response.json()["status"] == "actif"


def test_d08_champ_sensible_remet_en_attente(client, owner):
    nouvelle_zone = get_or_make_zone(ZoneLevel.VILLE_VILLAGE)
    cas = [
        {"name": "Nouveau nom"},
        {"zone": nouvelle_zone.pk},
        {"phone_anchor": "+237677000001"},
        {"type_compte": "entreprise", "forme_juridique": "sarl"},
    ]
    for changement in cas:
        user = make_owner()
        profile = active_profile(user)
        response = patch(connected(user), changement)
        assert response.status_code == 200, (changement, response.content)
        assert response.json()["status"] == "en_attente_validation"
        profile.refresh_from_db()
        assert profile.status == BusinessStatus.PENDING
        assert not BusinessProfile.objects.visible().filter(pk=profile.pk).exists()


def test_profil_en_attente_reste_en_attente(client, owner):
    profile = make_profile(owner=owner)
    assert patch(client, {"name": "Autre"}).json()["status"] == "en_attente_validation"
    assert patch(client, {"description": "x"}).json()["status"] == "en_attente_validation"
    profile.refresh_from_db()
    assert profile.status == BusinessStatus.PENDING


def test_le_client_ne_peut_pas_imposer_le_statut_au_patch(client, owner):
    profile = make_profile(owner=owner)
    response = patch(client, {"status": "actif", "motif_rejet": "x", "cni_verifiee": True,
                              "description": "ok"})
    assert response.status_code == 200
    profile.refresh_from_db()
    assert profile.status == BusinessStatus.PENDING
    assert profile.cni_verifiee is False


# --- 6. Profil rejeté corrigé et renvoyé -------------------------------------------------


def rejected(owner):
    return make_profile(
        owner=owner, status=BusinessStatus.REJECTED, motif_rejet="Photo floue",
        name="Nom à corriger",
    )


def test_profil_rejete_corrige_repasse_en_attente(client, owner):
    profile = rejected(owner)
    assert client.get(ME).json()["motif_rejet"] == "Photo floue"
    response = patch(client, {"name": "Nom corrigé", "photo": "@photo"})
    assert response.status_code == 200
    assert response.json()["status"] == "en_attente_validation"
    assert response.json()["motif_rejet"] == ""
    profile.refresh_from_db()
    assert (profile.status, profile.motif_rejet) == (BusinessStatus.PENDING, "")
    assert profile.name == "Nom corrigé"


def test_profil_rejete_meme_une_correction_simple_le_renvoie(client, owner):
    profile = rejected(owner)
    assert patch(client, {"description": "Précisions"}).json()["status"] == "en_attente_validation"
    profile.refresh_from_db()
    assert profile.motif_rejet == ""


def test_patch_vide_ou_invalide_ne_change_pas_un_profil_rejete(client, owner):
    profile = rejected(owner)
    assert patch(client, {}).status_code == 200
    assert fields_of(patch(client, {"zone": get_or_make_zone(ZoneLevel.REGION).pk}))
    assert fields_of(patch(client, {"photo": "../x"}))
    profile.refresh_from_db()
    assert (profile.status, profile.motif_rejet) == (BusinessStatus.REJECTED, "Photo floue")
    assert client.get(ME).json()["status"] == "rejete"


# --- Changement de type ------------------------------------------------------------------


def test_changement_de_type_exige_de_vider_les_champs_de_l_ancien(client, owner):
    profile = active_profile(owner, secteur=get_sector(), description_activite="Fruits")
    profile.sous_categories.set(subs_of(get_sector(), 2))
    vers_prestataire = {
        "type_compte": "prestataire_service",
        "categorie_service": get_service_category().pk, "cni_photo": CNI,
    }
    # Sans vider le secteur, la description d'activité et les sous-catégories : 400 explicite.
    errors = fields_of(patch(client, vers_prestataire))
    assert {"secteur", "description_activite"} <= set(errors)
    errors = fields_of(patch(client, {**vers_prestataire, "secteur": None,
                                      "description_activite": ""}))
    assert "sous_categories" in errors
    profile.refresh_from_db()
    assert profile.type_compte == "boutique"
    assert profile.sous_categories.count() == 2  # rien n'a été vidé en silence
    response = patch(client, {**vers_prestataire, "secteur": None, "description_activite": "",
                              "sous_categories": []})
    assert response.status_code == 200, response.content
    assert response.json()["type_compte"] == "prestataire_service"
    assert response.json()["status"] == "en_attente_validation"  # D-08
    profile.refresh_from_db()
    assert profile.secteur is None
    assert profile.sous_categories.count() == 0
