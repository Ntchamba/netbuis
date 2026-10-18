"""BusinessProfile (T025) : champs, contraintes par type, détails de structure, M2M, secret du
numéro ancré et de la CNI, admin."""
import importlib
import importlib.util
import inspect
import pkgutil

import pytest
from django.apps import apps as django_apps
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.test import Client
from rest_framework import serializers

from apps.accounts.models import User
from apps.accounts.permissions import BUSINESS_STATUS_ACTIVE
from apps.business.admin import BusinessProfileAdminForm
from apps.business.models import (
    AccountType,
    BusinessProfile,
    BusinessStatus,
    validate_subcategories,
)
from apps.catalog.models import Subcategory
from apps.core.utils.phone import mask_phone
from apps.geo.models import ZoneLevel
from tests.factories.business_factory import (
    get_or_make_zone,
    get_sector,
    get_service_category,
    get_structure_type,
    make_owner,
    make_profile,
    profile_values,
)
from tests.factories.catalog_factory import make_sector, make_subcategory
from tests.factories.zone_factory import make_maroua_chain

pytestmark = pytest.mark.django_db

SECTOR_TYPES = ["boutique", "entreprise", "particulier_vendeur"]


def errors_of(type_compte, **extra):
    """Les erreurs de validation levées à l'enregistrement (dict champ -> messages)."""
    with pytest.raises(ValidationError) as caught:
        make_profile(type_compte, **extra)
    return caught.value.message_dict


# --- Création valide : un cas par type --------------------------------------------------


@pytest.mark.parametrize("type_compte", list(AccountType.values))
def test_un_profil_valide_par_type(type_compte):
    profile = make_profile(type_compte)
    assert profile.pk is not None
    assert profile.type_compte == type_compte


def test_valeurs_par_defaut():
    profile = make_profile()
    assert profile.status == "en_attente_validation"
    assert profile.whatsapp_available is True
    assert (profile.calls_count, profile.views_count) == (0, 0)
    assert profile.repere == ""


def test_champs_supplementaires_des_maquettes():
    profile = make_profile(repere="À côté du Grand Manguier", whatsapp_available=False)
    profile.refresh_from_db()
    assert profile.repere == "À côté du Grand Manguier"
    assert profile.whatsapp_available is False


def test_statut_actif_est_la_valeur_lue_par_accounts():
    assert BusinessStatus.ACTIVE == BUSINESS_STATUS_ACTIVE == "actif"


def test_le_lien_avec_le_compte_alimente_business_profile_or_none():
    owner = make_owner()
    assert owner.business_profile_or_none is None
    profile = make_profile(owner=owner)
    owner = User.objects.get(pk=owner.pk)
    assert owner.business_profile == profile
    assert owner.business_profile_or_none == profile


def test_str_sans_numero():
    profile = make_profile(name="Chez Ali")
    assert str(profile) == "Chez Ali (Commerce)"
    assert profile.phone_anchor not in str(profile)


def test_compteurs_non_editables():
    assert BusinessProfile._meta.get_field("calls_count").editable is False
    assert BusinessProfile._meta.get_field("views_count").editable is False


# --- Un seul profil par compte --------------------------------------------------------


def test_un_compte_a_au_plus_un_profil():
    owner = make_owner()
    make_profile(owner=owner)
    with pytest.raises(IntegrityError), transaction.atomic():
        make_profile("entreprise", owner=owner)


# --- Lieu -----------------------------------------------------------------------------


@pytest.mark.parametrize("level", [ZoneLevel.VILLE_VILLAGE, ZoneLevel.QUARTIER])
def test_lieu_ville_ou_quartier_accepte(level):
    make_maroua_chain()
    assert make_profile(zone=get_or_make_zone(level)).zone.level == level


@pytest.mark.parametrize(
    "level", [ZoneLevel.PAYS, ZoneLevel.REGION, ZoneLevel.DEPARTEMENT]
)
def test_lieu_trop_haut_refuse(level):
    make_maroua_chain()
    assert "zone" in errors_of("boutique", zone=get_or_make_zone(level))


def test_lieu_repere_refuse():
    _, _, _, ville, _ = make_maroua_chain()
    from tests.factories.zone_factory import make_zone

    repere = make_zone("Grand Manguier", ZoneLevel.REPERE, ville)
    assert "zone" in errors_of("boutique", zone=repere)


# --- Champs obligatoires ----------------------------------------------------------------


@pytest.mark.parametrize(
    "field", ["name", "photo", "representant_nom", "representant_photo", "phone_anchor"]
)
def test_champ_commun_obligatoire(field):
    assert field in errors_of("boutique", **{field: ""})


def test_prestataire_sans_cni_refuse():
    assert "cni_photo" in errors_of("prestataire_service", cni_photo="")


def test_prestataire_sans_categorie_refuse():
    assert "categorie_service" in errors_of("prestataire_service", categorie_service=None)


def test_entreprise_sans_forme_juridique_refusee():
    assert "forme_juridique" in errors_of("entreprise", forme_juridique="")


def test_structure_sans_type_refusee():
    assert "structure_type" in errors_of("structure", structure_type=None)


@pytest.mark.parametrize("type_compte", SECTOR_TYPES)
def test_secteur_obligatoire_pour_commerce_entreprise_particulier(type_compte):
    assert "secteur" in errors_of(type_compte, secteur=None)


# --- Numéro ancré -----------------------------------------------------------------------


@pytest.mark.parametrize("bad", ["677123456", "+33612345678", "+2375", "abc", "+237 677 12 34 56"])
def test_numero_invalide_refuse(bad):
    assert "phone_anchor" in errors_of("boutique", phone_anchor=bad)


def test_numero_valide_enregistre_tel_quel():
    profile = make_profile(phone_anchor="+237677123456")
    profile.refresh_from_db()
    assert profile.phone_anchor == "+237677123456"


# --- Champs d'un type interdits aux autres --------------------------------------------


def test_forme_juridique_interdite_hors_entreprise():
    for type_compte in ("boutique", "particulier_vendeur", "prestataire_service", "structure"):
        assert "forme_juridique" in errors_of(type_compte, forme_juridique="sarl")
    assert "rccm" in errors_of("boutique", rccm="RC/MAR/2020/B/1")


def test_rccm_facultatif_pour_entreprise():
    assert make_profile("entreprise", rccm="").rccm == ""
    assert make_profile("entreprise", rccm="RC/MAR/2020/B/1").rccm == "RC/MAR/2020/B/1"


def test_forme_juridique_inconnue_refusee_par_la_base_de_choix():
    profile = make_profile("entreprise")
    profile.forme_juridique = "inconnue"
    with pytest.raises(ValidationError):
        profile.full_clean()


@pytest.mark.parametrize(
    "type_compte", ["boutique", "entreprise", "particulier_vendeur", "structure"]
)
@pytest.mark.parametrize("field", ["cni_photo", "diplome_photo"])
def test_pieces_du_prestataire_interdites_aux_autres(type_compte, field):
    assert field in errors_of(type_compte, **{field: "prive/x.jpg"})


def test_categorie_service_et_cni_verifiee_interdites_aux_autres():
    assert "categorie_service" in errors_of("boutique", categorie_service=get_service_category())
    assert "cni_verifiee" in errors_of("boutique", cni_verifiee=True)


def test_diplome_facultatif_pour_prestataire():
    assert make_profile("prestataire_service").diplome_photo == ""
    assert make_profile("prestataire_service", diplome_photo="prive/d.jpg").diplome_photo


@pytest.mark.parametrize("type_compte", ["prestataire_service", "structure"])
def test_secteur_interdit_pour_prestataire_et_structure(type_compte):
    assert "secteur" in errors_of(type_compte, secteur=get_sector())
    assert "description_activite" in errors_of(type_compte, description_activite="Vente de riz")
    assert "secteur_libre" in errors_of(type_compte, secteur_libre="Quelque chose")


def test_structure_interdite_aux_autres_types():
    assert "structure_type" in errors_of("boutique", structure_type=get_structure_type())
    assert "structure_type_libre" in errors_of("boutique", structure_type_libre="Cinéma")
    assert "cuisine" in errors_of("entreprise", cuisine="fast_food")


# --- Libre quand « Autre » ----------------------------------------------------------------


def test_secteur_libre_seulement_pour_autre():
    assert "secteur_libre" in errors_of("boutique", secteur_libre="Quincaillerie")
    autre = get_sector("autre", "Autre")
    assert make_profile("boutique", secteur=autre, secteur_libre="Quincaillerie").secteur_libre
    assert "secteur_libre" in errors_of("boutique", secteur=autre, secteur_libre="")


def test_categorie_service_libre_seulement_pour_autre():
    assert "categorie_service_libre" in errors_of(
        "prestataire_service", categorie_service_libre="Dressage"
    )
    autre = get_service_category("autre", "Autre")
    profile = make_profile(
        "prestataire_service", categorie_service=autre, categorie_service_libre="Dressage"
    )
    assert profile.categorie_service_libre == "Dressage"
    assert "categorie_service_libre" in errors_of(
        "prestataire_service", categorie_service=autre, categorie_service_libre=""
    )


def test_structure_type_libre_seulement_pour_autre():
    assert "structure_type_libre" in errors_of("structure", structure_type_libre="Cinéma")
    autre = get_structure_type("autre", "Autre")
    assert make_profile("structure", structure_type=autre, structure_type_libre="Cinéma")
    assert "structure_type_libre" in errors_of(
        "structure", structure_type=autre, structure_type_libre=""
    )


# --- Motif de rejet -----------------------------------------------------------------------


def test_motif_rejet_seulement_si_rejete():
    assert "motif_rejet" in errors_of("boutique", motif_rejet="Photo floue")
    assert "motif_rejet" in errors_of("boutique", status="actif", motif_rejet="Photo floue")
    profile = make_profile("boutique", status="rejete", motif_rejet="Photo floue")
    assert profile.motif_rejet == "Photo floue"


def test_statut_inconnu_refuse():
    assert "status" in errors_of("boutique", status="suspendu")


# --- Détails de structure : un champ par ligne de la spec -----------------------------------

DETAILS_VALIDES = {
    "supermarche": {"rayons": ["produits_frais", "boissons"]},
    "restaurant": {"cuisine": "camerounaise", "livraison": True, "horaires": "8h-22h"},
    "hotel": {"standing": "confort", "nombre_chambres": 24, "equipements": ["wifi", "parking"]},
    "sante": {"numero_agrement": "AG-123", "specialites": ["pediatrie", "dentisterie"]},
}
CHAMP_ETRANGER = {
    "supermarche": {"cuisine": "fast_food"},
    "restaurant": {"rayons": ["boissons"]},
    "hotel": {"horaires": "24h/24"},
    "sante": {"nombre_chambres": 10},
}
NOMS_STRUCTURE = {
    "supermarche": "Supermarché", "restaurant": "Restaurant", "hotel": "Hôtel",
    "sante": "Centre de santé",
}


@pytest.mark.parametrize("code", list(DETAILS_VALIDES))
def test_details_propres_au_type_acceptes(code):
    structure_type = get_structure_type(code, NOMS_STRUCTURE[code])
    profile = make_profile("structure", structure_type=structure_type, **DETAILS_VALIDES[code])
    profile.refresh_from_db()
    for field, value in DETAILS_VALIDES[code].items():
        assert getattr(profile, field) == value


@pytest.mark.parametrize("code", list(DETAILS_VALIDES))
def test_details_d_un_autre_type_refuses(code):
    structure_type = get_structure_type(code, NOMS_STRUCTURE[code])
    for field, value in CHAMP_ETRANGER[code].items():
        errors = errors_of("structure", structure_type=structure_type, **{field: value})
        assert field in errors


@pytest.mark.parametrize("code", list(DETAILS_VALIDES))
@pytest.mark.parametrize("other", list(DETAILS_VALIDES))
def test_tous_les_details_croises(code, other):
    if code == other:
        return
    structure_type = get_structure_type(code, NOMS_STRUCTURE[code])
    errors = errors_of("structure", structure_type=structure_type, **DETAILS_VALIDES[other])
    assert set(DETAILS_VALIDES[other]) <= set(errors)


def test_type_autre_n_a_aucun_detail():
    autre = get_structure_type("autre", "Autre")
    errors = errors_of(
        "structure", structure_type=autre, structure_type_libre="Cinéma", horaires="20h"
    )
    assert "horaires" in errors


def test_listes_valeurs_inconnues_ou_repetees_refusees():
    structure_type = get_structure_type("supermarche", "Supermarché")
    assert "rayons" in errors_of("structure", structure_type=structure_type, rayons=["poissons"])
    assert "rayons" in errors_of(
        "structure", structure_type=structure_type, rayons=["boissons", "boissons"]
    )
    assert "rayons" in errors_of("structure", structure_type=structure_type, rayons="boissons")


def test_valeurs_de_choix_inconnues_refusees():
    hotel = get_structure_type("hotel", "Hôtel")
    profile = make_profile("structure", structure_type=hotel, standing="confort")
    profile.standing = "luxe"
    with pytest.raises(ValidationError):
        profile.full_clean()


def test_nombre_de_chambres_au_moins_un():
    hotel = get_structure_type("hotel", "Hôtel")
    assert "nombre_chambres" in errors_of("structure", structure_type=hotel, nombre_chambres=0)


def test_les_plafonds_de_trois_ne_sont_pas_dans_le_modele():
    """Rayons et spécialités sont stockés tels quels : le plafond (abonnement) est en T026."""
    supermarche = get_structure_type("supermarche", "Supermarché")
    rayons = ["produits_frais", "boissons", "alimentation_generale", "autre"]
    assert len(make_profile("structure", structure_type=supermarche, rayons=rayons).rayons) == 4


# --- Contraintes en base (en plus de la validation) ----------------------------------------


@pytest.mark.parametrize(
    "type_compte, change",
    [
        ("boutique", {"forme_juridique": "sarl"}),
        ("boutique", {"cni_photo": "prive/x.jpg"}),
        ("boutique", {"cni_verifiee": True}),
        ("boutique", {"structure_type_libre": "x"}),
        ("boutique", {"motif_rejet": "x"}),
        ("prestataire_service", {"secteur": "SECTEUR"}),
        ("structure", {"description_activite": "x"}),
    ],
)
def test_la_base_refuse_aussi_les_champs_interdits(type_compte, change):
    profile = make_profile(type_compte)
    if change.get("secteur") == "SECTEUR":
        change = {"secteur": get_sector()}
    with pytest.raises(IntegrityError), transaction.atomic():
        BusinessProfile.objects.filter(pk=profile.pk).update(**change)


# --- Sous-catégories (M2M) ----------------------------------------------------------------


def test_sous_categories_du_secteur_acceptees():
    alimentation = get_sector()
    profile = make_profile("boutique", secteur=alimentation)
    fruits = make_subcategory(alimentation, "fruits", "Fruits")
    validate_subcategories(profile, [fruits])
    profile.sous_categories.add(fruits)
    assert list(profile.sous_categories.all()) == [fruits]


def test_sous_categorie_d_un_autre_secteur_refusee():
    profile = make_profile("boutique", secteur=get_sector())
    autre_secteur = make_sector("immobilier", "Immobilier")
    terrain = make_subcategory(autre_secteur, "terrain", "Terrain")
    with pytest.raises(ValidationError) as caught:
        validate_subcategories(profile, [terrain])
    assert "sous_categories" in caught.value.message_dict
    with pytest.raises(ValidationError), transaction.atomic():
        profile.sous_categories.add(terrain)
    assert profile.sous_categories.count() == 0


def test_sous_categorie_refusee_a_l_ajout_depuis_la_sous_categorie():
    profile = make_profile("boutique", secteur=get_sector())
    terrain = make_subcategory(make_sector("immobilier", "Immobilier"), "terrain", "Terrain")
    with pytest.raises(ValidationError):
        terrain.business_profiles.add(profile)


@pytest.mark.parametrize("type_compte", ["prestataire_service", "structure"])
def test_sous_categories_interdites_pour_prestataire_et_structure(type_compte):
    profile = make_profile(type_compte)
    fruits = make_subcategory(get_sector(), "fruits", "Fruits")
    with pytest.raises(ValidationError):
        validate_subcategories(profile, [fruits])
    with pytest.raises(ValidationError):
        profile.sous_categories.add(fruits)


def test_sous_categories_vides_toujours_acceptees():
    validate_subcategories(make_profile("prestataire_service"), [])


def test_pas_de_plafond_de_trois_dans_validate_subcategories():
    alimentation = get_sector()
    profile = make_profile("boutique", secteur=alimentation)
    subs = [make_subcategory(alimentation, f"s{i}", f"S{i}") for i in range(4)]
    validate_subcategories(profile, subs)
    assert Subcategory.objects.count() == 4


# --- Le numéro ancré et la CNI ne sortent par aucun sérialiseur ------------------------------

# Sérialiseurs d'ADMINISTRATION autorisés à montrer `cni_photo` (jamais `phone_anchor`).
# Format « module.NomDeClasse ». Vide aujourd'hui : aucun sérialiseur ne l'expose.
CNI_ADMIN_SERIALIZERS: set[str] = set()
SECRET_FIELDS = {"phone_anchor", "cni_photo"}


def _serializer_modules():
    for config in django_apps.get_app_configs():
        if not config.name.startswith("apps."):
            continue
        package = f"{config.name}.serializers"
        if importlib.util.find_spec(package) is None:
            continue
        root = importlib.import_module(package)
        yield root
        for info in pkgutil.walk_packages(root.__path__, prefix=f"{package}."):
            yield importlib.import_module(info.name)


def all_serializer_classes():
    found = {}
    for module in _serializer_modules():
        for _, obj in inspect.getmembers(module, inspect.isclass):
            if issubclass(obj, serializers.BaseSerializer):
                found[f"{obj.__module__}.{obj.__name__}"] = obj
    return found


def _field_names(serializer):
    """Noms et sources des champs LISIBLES, sous-sérialiseurs inclus. Un champ en écriture
    seule (`write_only=True`) n'est jamais renvoyé : ce n'est pas une exposition."""
    names = set()
    if isinstance(serializer, serializers.ListSerializer):
        serializer = serializer.child
    for name, field in serializer.fields.items():
        if field.write_only:
            continue
        names.update({name, getattr(field, "source", None) or name})
        if isinstance(field, (serializers.Serializer, serializers.ListSerializer)):
            names |= _field_names(field)
    return names


def exposed_secrets(classes, cni_allowed=frozenset()):
    """{« module.Classe »: champs secrets exposés} pour les sérialiseurs de `classes`."""
    problems = {}
    for label, cls in classes.items():
        if not issubclass(cls, serializers.Serializer):
            continue
        exposed = _field_names(cls()) & SECRET_FIELDS
        if label in cni_allowed:
            exposed -= {"cni_photo"}
        if exposed:
            problems[label] = sorted(exposed)
    return problems


def test_les_sources_de_serialiseurs_sont_bien_parcourues():
    classes = all_serializer_classes()
    assert "apps.accounts.serializers.user.UserSerializer" in classes or any(
        label.startswith("apps.accounts.serializers.") for label in classes
    )


def test_aucun_serialiseur_n_expose_le_numero_ancre_ni_la_cni():
    problems = exposed_secrets(all_serializer_classes(), cni_allowed=CNI_ADMIN_SERIALIZERS)
    assert problems == {}


def test_le_detecteur_signale_un_serialiseur_fautif():
    class TousLesChamps(serializers.ModelSerializer):
        class Meta:
            model = BusinessProfile
            fields = "__all__"

    class ListeExplicite(serializers.ModelSerializer):
        class Meta:
            model = BusinessProfile
            fields = ["name", "cni_photo"]

    class ChampRenomme(serializers.ModelSerializer):
        numero = serializers.CharField(source="phone_anchor")

        class Meta:
            model = BusinessProfile
            fields = ["name", "numero"]

    class Sain(serializers.ModelSerializer):
        class Meta:
            model = BusinessProfile
            fields = ["name", "repere"]

    class Imbrique(serializers.Serializer):
        profil = ListeExplicite()

    classes = {
        "t.TousLesChamps": TousLesChamps, "t.ListeExplicite": ListeExplicite,
        "t.ChampRenomme": ChampRenomme, "t.Sain": Sain, "t.Imbrique": Imbrique,
    }
    problems = exposed_secrets(classes)
    assert problems["t.TousLesChamps"] == ["cni_photo", "phone_anchor"]
    assert problems["t.ListeExplicite"] == ["cni_photo"]
    assert problems["t.ChampRenomme"] == ["phone_anchor"]
    assert problems["t.Imbrique"] == ["cni_photo"]
    assert "t.Sain" not in problems


def test_la_liste_blanche_admin_ne_couvre_que_la_cni():
    class AdminCni(serializers.ModelSerializer):
        class Meta:
            model = BusinessProfile
            fields = ["name", "cni_photo", "phone_anchor"]

    problems = exposed_secrets({"t.AdminCni": AdminCni}, cni_allowed={"t.AdminCni"})
    assert problems == {"t.AdminCni": ["phone_anchor"]}


def test_un_champ_en_ecriture_seule_n_est_pas_une_exposition():
    class Ecriture(serializers.ModelSerializer):
        phone_anchor = serializers.CharField(write_only=True)
        cni_photo = serializers.CharField(write_only=True)

        class Meta:
            model = BusinessProfile
            fields = ["name", "phone_anchor", "cni_photo"]

    class Lisible(serializers.ModelSerializer):
        phone_anchor = serializers.CharField()  # lisible : signalé

        class Meta:
            model = BusinessProfile
            fields = ["name", "phone_anchor"]

    class ExtraKwargs(serializers.ModelSerializer):
        class Meta:
            model = BusinessProfile
            fields = ["name", "phone_anchor", "cni_photo"]
            extra_kwargs = {"phone_anchor": {"write_only": True}}  # cni_photo reste lisible

    class Imbrique(serializers.Serializer):
        profil = Ecriture()

    problems = exposed_secrets({
        "t.Ecriture": Ecriture, "t.Lisible": Lisible, "t.ExtraKwargs": ExtraKwargs,
        "t.Imbrique": Imbrique,
    })
    assert problems == {"t.Lisible": ["phone_anchor"], "t.ExtraKwargs": ["cni_photo"]}


# --- Admin --------------------------------------------------------------------------------


@pytest.fixture
def admin_client():
    user = make_owner(is_admin=True, is_staff=True, is_superuser=True)
    client = Client()
    client.force_login(user)
    return client


def test_admin_liste_sans_numero_ni_chemin_cni(admin_client):
    profile = make_profile("prestataire_service", name="Plombier Test")
    response = admin_client.get("/django-admin/business/businessprofile/")
    assert response.status_code == 200
    html = response.content.decode()
    assert "Plombier Test" in html
    assert profile.phone_anchor not in html
    assert profile.cni_photo not in html


def test_admin_fiche_numero_masque_et_sans_cni(admin_client):
    profile = make_profile("prestataire_service", phone_anchor="+237677123456")
    response = admin_client.get(f"/django-admin/business/businessprofile/{profile.pk}/change/")
    assert response.status_code == 200
    html = response.content.decode()
    assert mask_phone("+237677123456") in html
    assert "677123456" not in html
    assert "prive/cni.jpg" not in html


def test_admin_n_ajoute_pas_de_profil(admin_client):
    assert admin_client.get("/django-admin/business/businessprofile/add/").status_code == 403


def test_admin_erreur_sur_un_champ_absent_du_formulaire_devient_generale():
    profile = make_profile("prestataire_service")
    form = BusinessProfileAdminForm(data={}, instance=profile)
    form.is_valid()
    form.errors.clear()
    form._update_errors(ValidationError({"cni_photo": "La photo de la CNI est obligatoire."}))
    assert "La photo de la CNI est obligatoire." in form.non_field_errors()


def test_profile_values_est_valide_pour_chaque_type():
    for type_compte in AccountType.values:
        assert profile_values(type_compte)["type_compte"] == type_compte
