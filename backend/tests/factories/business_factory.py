"""Fabrique de comptes business valides, un jeu de valeurs par type de compte."""
from itertools import count

from apps.accounts.models import User
from apps.business.models import AccountType, BusinessProfile
from apps.catalog.models import Sector, ServiceCategory, StructureType
from apps.geo.models import Zone, ZoneLevel
from tests.factories.zone_factory import make_maroua_chain

_numbers = count(1)


def make_owner(**extra) -> User:
    """Un compte simple au numéro unique (6 00 00 00 XX est réservé aux essais)."""
    return User.objects.create(phone=f"+2376{next(_numbers):08d}", **extra)


def get_or_make_zone(level=ZoneLevel.QUARTIER) -> Zone:
    if not Zone.objects.exists():
        make_maroua_chain()
    return Zone.objects.filter(level=level).first()


def get_sector(code="alimentation", name="Alimentation") -> Sector:
    return Sector.objects.get_or_create(code=code, defaults={"name": name})[0]


def get_service_category(code="technique_reparation", name="Technique & Réparation"):
    return ServiceCategory.objects.get_or_create(code=code, defaults={"name": name})[0]


def get_structure_type(code="restaurant", name="Restaurant") -> StructureType:
    return StructureType.objects.get_or_create(code=code, defaults={"name": name})[0]


def profile_values(type_compte=AccountType.BOUTIQUE, **extra) -> dict:
    """Valeurs valides pour `type_compte` (sans propriétaire). `extra` les remplace."""
    values = {
        "type_compte": type_compte,
        "name": "Boutique de démonstration",
        "zone": get_or_make_zone(),
        "photo": "profils/photo.jpg",
        "representant_nom": "Personne de démonstration",
        "representant_photo": "profils/representant.jpg",
        "phone_anchor": f"+2376{next(_numbers):08d}",
    }
    if type_compte in (AccountType.BOUTIQUE, AccountType.ENTREPRISE,
                       AccountType.PARTICULIER_VENDEUR):
        values["secteur"] = get_sector()
    if type_compte == AccountType.ENTREPRISE:
        values["forme_juridique"] = "sarl"
    if type_compte == AccountType.PRESTATAIRE_SERVICE:
        values["categorie_service"] = get_service_category()
        values["cni_photo"] = "prive/cni.jpg"
    if type_compte == AccountType.STRUCTURE:
        values["structure_type"] = get_structure_type()
    values.update(extra)
    return values


def make_profile(type_compte=AccountType.BOUTIQUE, owner=None, **extra) -> BusinessProfile:
    values = profile_values(type_compte, **extra)
    return BusinessProfile.objects.create(owner=owner or make_owner(), **values)
