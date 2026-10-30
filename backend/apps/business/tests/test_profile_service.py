"""Service du compte business (T026) : visibilité publique, création, plafonds, transaction."""
import pytest
from rest_framework.exceptions import ValidationError

from apps.business.models import BusinessProfile, BusinessStatus
from apps.business.services import profile_service
from apps.business.services.profile_service import (
    BusinessExists,
    NoBusiness,
    SubscriptionRequired,
)
from tests.factories.business_factory import (
    get_sector,
    make_owner,
    make_profile,
    make_subscription,
    profile_values,
)
from tests.factories.catalog_factory import make_sector, make_subcategory

pytestmark = pytest.mark.django_db


def service_values(type_compte="boutique", **extra):
    return profile_values(type_compte, **extra)


# --- Critère 7 : visible() est l'unique définition de la visibilité publique -----------------


def test_visible_inclut_un_profil_actif_d_un_compte_normal():
    profile = make_profile(status=BusinessStatus.ACTIVE)
    assert list(BusinessProfile.objects.visible()) == [profile]


@pytest.mark.parametrize("flag", ["is_deleted", "is_blocked"])
def test_visible_exclut_un_compte_supprime_ou_bloque(flag):
    owner = make_owner(**{flag: True})
    make_profile(owner=owner, status=BusinessStatus.ACTIVE)
    assert not BusinessProfile.objects.visible().exists()


def test_visible_exclut_un_compte_inactif():
    make_profile(owner=make_owner(is_active=False), status=BusinessStatus.ACTIVE)
    assert not BusinessProfile.objects.visible().exists()


@pytest.mark.parametrize("status", [BusinessStatus.PENDING, BusinessStatus.REJECTED])
def test_visible_exclut_en_attente_et_rejete(status):
    extra = {"motif_rejet": "Photo floue"} if status == BusinessStatus.REJECTED else {}
    make_profile(status=status, **extra)
    assert not BusinessProfile.objects.visible().exists()


def test_le_profil_disparait_quand_son_compte_est_supprime():
    profile = make_profile(status=BusinessStatus.ACTIVE)
    assert BusinessProfile.objects.visible().filter(pk=profile.pk).exists()
    owner = profile.owner
    owner.is_deleted = True
    owner.save()
    assert not BusinessProfile.objects.visible().filter(pk=profile.pk).exists()
    assert BusinessProfile.objects.filter(pk=profile.pk).exists()  # les données restent


def test_visible_se_compose_avec_d_autres_filtres():
    make_profile(status=BusinessStatus.ACTIVE, name="Un")
    make_profile(status=BusinessStatus.ACTIVE, name="Deux")
    assert BusinessProfile.objects.filter(name="Un").visible().count() == 1


# --- Création / lecture ------------------------------------------------------------------


def test_create_profile_force_le_statut_et_le_proprietaire():
    owner = make_owner()
    profile = profile_service.create_profile(owner, service_values(status="actif"))
    assert profile.owner == owner
    assert profile.status == BusinessStatus.PENDING


def test_create_profile_refuse_un_second_profil():
    owner = make_owner()
    profile_service.create_profile(owner, service_values())
    with pytest.raises(BusinessExists):
        profile_service.create_profile(owner, service_values())


def test_create_profile_invalide_ne_cree_rien():
    owner = make_owner()
    values = service_values()
    values["representant_photo"] = ""
    with pytest.raises(ValidationError) as caught:
        profile_service.create_profile(owner, values)
    assert "representant_photo" in caught.value.detail
    assert not BusinessProfile.objects.filter(owner=owner).exists()


def test_get_own_profile():
    owner = make_owner()
    with pytest.raises(NoBusiness):
        profile_service.get_own_profile(owner)
    profile = make_profile(owner=owner)
    assert profile_service.get_own_profile(owner) == profile


# --- Plafonds ----------------------------------------------------------------------------


def test_plafond_quatre_sous_categories_a_la_creation_sans_abonnement():
    secteur = get_sector()
    subs = [make_subcategory(secteur, f"s{i}", f"S{i}") for i in range(4)]
    owner = make_owner()
    with pytest.raises(SubscriptionRequired) as caught:
        profile_service.create_profile(owner, service_values(sous_categories=subs))
    assert caught.value.get_codes() == "SUBSCRIPTION_REQUIRED"
    assert not BusinessProfile.objects.filter(owner=owner).exists()
    profile = profile_service.create_profile(owner, service_values(sous_categories=subs[:3]))
    assert profile.sous_categories.count() == 3


def test_update_abonne_peut_depasser_trois():
    secteur = get_sector()
    profile = make_profile(secteur=secteur)
    make_subscription(profile)
    subs = [make_subcategory(secteur, f"s{i}", f"S{i}") for i in range(5)]
    profile_service.update_profile(profile, {"sous_categories": subs})
    assert profile.sous_categories.count() == 5


def test_update_sous_categorie_d_un_autre_secteur_annule_la_transaction():
    secteur = get_sector()
    profile = make_profile(secteur=secteur)
    bonne = make_subcategory(secteur, "bonne", "Bonne")
    autre = make_subcategory(make_sector("immobilier", "Immobilier"), "terrain", "Terrain")
    with pytest.raises(ValidationError):
        profile_service.update_profile(
            profile, {"description": "Changée", "sous_categories": [bonne, autre]}
        )
    profile.refresh_from_db()
    assert profile.description == ""
    assert profile.sous_categories.count() == 0


def test_update_sans_donnees_ne_change_rien():
    profile = make_profile(status=BusinessStatus.REJECTED, motif_rejet="Photo floue")
    profile_service.update_profile(profile, {})
    profile.refresh_from_db()
    assert profile.status == BusinessStatus.REJECTED


def test_create_profile_ancre_le_numero_du_compte_et_ignore_celui_du_client():
    owner, autre = make_owner(), make_owner()
    profile = profile_service.create_profile(owner, service_values(phone_anchor=autre.phone))
    assert profile.phone_anchor == owner.phone != autre.phone


def test_create_profile_sans_photo_du_commerce():
    profile = profile_service.create_profile(make_owner(), service_values(photo=""))
    assert profile.photo == ""


def test_update_profile_ignore_phone_anchor_et_garde_le_statut():
    profile = make_profile(status=BusinessStatus.ACTIVE)
    ancre = profile.phone_anchor
    updated = profile_service.update_profile(profile, {"phone_anchor": "+237677000001"})
    assert updated.phone_anchor == ancre and updated.status == BusinessStatus.ACTIVE
    assert "phone_anchor" not in profile_service.SENSITIVE_FIELDS
