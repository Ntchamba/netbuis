"""Données de démonstration (T028) : commerces FICTIFS de Maroua, pour montrer l'application
et mesurer les performances (T040, T122).

Tout est visiblement fictif et reconnaissable :
- le téléphone du compte propriétaire ET le numéro ancré du profil sont dans le bloc
  `+237600xxxxxx`, réservé aux données fictives et aux essais (D-18 : « 6 00 00 00 XX ») ;
  le commerce n° i a le numéro `+237` + `600000000 + i` (donc `+2376000000XX` jusqu'à 99) ;
- le nom du commerce commence par `[DÉMO] ` ; le propriétaire s'appelle « Responsable Démo NN » ;
- aucun fichier n'est écrit : les photos sont des clés de stockage AU FORMAT du serveur
  (`u<id>/<kind>/<32 hex>.<ext>`, `StorageService.new_key`) qui ne pointent vers rien.

Reconnaissance (idempotence, `--flush`) : un commerce de démonstration est un profil dont le nom
commence par `[DÉMO] ` ET dont le propriétaire a un téléphone du bloc réservé. Les deux conditions
sont toujours vérifiées ensemble : un vrai profil n'est jamais touché.

Répartition déterministe (arithmétique sur l'index, aucun hasard) : relancer donne les mêmes
fiches. Chaque profil est enregistré par `save()` donc validé par `clean()`.

Pour étendre la commande (offres T037, publications T090, abonnements T110) : ajouter une
fonction `add_<chose>(profile, i, refs)` appelée depuis `create_demo_profile`, qui ne s'exécute
que pour un profil NEUF (la création est donc idempotente de bout en bout).
"""
from __future__ import annotations

import re
from dataclasses import dataclass

from django.db import transaction

from apps.accounts.models import User
from apps.business.models import AccountType, BusinessProfile, BusinessStatus
from apps.business.models.profile import (
    SECTOR_TYPES,
    Aisle,
    Amenity,
    Cuisine,
    LegalForm,
    Speciality,
    Standing,
)
from apps.business.services.storage_service import JPEG, new_key
from apps.catalog.models import Sector, ServiceCategory, StructureType
from apps.core.utils.phone import normalize_phone
from apps.geo.models import Zone, ZoneLevel

DEMO_PREFIX = "[DÉMO] "
OWNER_PREFIX = "Responsable Démo "
PHONE_BLOCK_REGEX = r"^\+237600[0-9]{6}$"  # bloc réservé aux données fictives
_PHONE_BLOCK = re.compile(PHONE_BLOCK_REGEX)
PHONE_BASE = 600000000
MAX_COUNT = 5000
DEFAULT_COUNT = 20
DESCRIPTION = "Fiche de démonstration — ne correspond à aucun commerce réel."
REJECT_REASON = "Fiche de démonstration rejetée."
PREREQUISITE_MESSAGE = "Lancez d'abord load_zones et seed_referentials."

TYPE_ROTATION = (
    AccountType.BOUTIQUE, AccountType.ENTREPRISE, AccountType.PARTICULIER_VENDEUR,
    AccountType.PRESTATAIRE_SERVICE, AccountType.STRUCTURE,
)
TYPE_LABELS = {
    AccountType.BOUTIQUE: "Boutique du Manguier",
    AccountType.ENTREPRISE: "Entreprise du Baobab",
    AccountType.PARTICULIER_VENDEUR: "Vendeur du Marché Imaginaire",
    AccountType.PRESTATAIRE_SERVICE: "Service du Rônier",
    AccountType.STRUCTURE: "Établissement du Karité",
}
STRUCTURE_CODES = ("supermarche", "restaurant", "hotel", "sante", "autre")
OTHER_CODE = "autre"
HORAIRES = "Horaires fictifs de démonstration"


class MissingReferentials(Exception):
    """Zones ou référentiels non chargés."""


def demo_phone(index: int) -> str:
    """Téléphone fictif du commerce n° `index` (1 à MAX_COUNT), dans le bloc réservé."""
    if not 1 <= index <= MAX_COUNT:
        raise ValueError(f"Index de démonstration hors limites : {index}.")
    return normalize_phone(str(PHONE_BASE + index))


def is_demo_phone(phone: str) -> bool:
    return bool(_PHONE_BLOCK.match(phone or ""))


@dataclass
class Referentials:
    """Référentiels lus UNE fois (aucune requête par commerce)."""

    zones: list  # quartiers de Maroua puis la ville
    sectors: list  # (secteur, [sous-catégories]) sans « Autre »
    service_categories: list
    structure_types: dict  # code -> StructureType


def load_referentials() -> Referentials:
    maroua = Zone.objects.filter(
        level=ZoneLevel.VILLE_VILLAGE, normalized_name="maroua", is_active=True
    ).first()
    quartiers = (
        list(Zone.objects.filter(
            level=ZoneLevel.QUARTIER, parent=maroua, is_active=True
        ).order_by("order", "normalized_name", "id"))
        if maroua else []
    )
    sectors = []
    for sector in Sector.objects.filter(is_active=True).exclude(code=OTHER_CODE).prefetch_related(
        "subcategories"
    ):
        subs = [s for s in sector.subcategories.all() if s.is_active]
        if subs:
            sectors.append((sector, subs))
    categories = list(ServiceCategory.objects.filter(is_active=True))
    structure_types = {
        st.code: st for st in StructureType.objects.filter(
            is_active=True, code__in=STRUCTURE_CODES
        )
    }
    if (
        len(quartiers) < 3 or not sectors or not categories
        or set(structure_types) != set(STRUCTURE_CODES)
    ):
        raise MissingReferentials(PREREQUISITE_MESSAGE)
    return Referentials(
        zones=[*quartiers, maroua], sectors=sectors, service_categories=categories,
        structure_types=structure_types,
    )


def demo_status(n: int) -> tuple[str, str]:
    """Statut et motif du commerce d'index base 0 `n` : 70 % actifs, 20 % en attente,
    10 % rejetés."""
    slot = (n + n // 5) % 10
    if slot == 9:
        return BusinessStatus.REJECTED, REJECT_REASON
    if slot >= 7:
        return BusinessStatus.PENDING, ""
    return BusinessStatus.ACTIVE, ""


def _pick(items: list, start: int, count: int) -> list:
    count = min(count, len(items))
    return [items[(start + k) % len(items)] for k in range(count)]


def _type_values(i: int, n: int, kind: str, refs: Referentials) -> tuple[dict, list]:
    """Champs propres au type de compte et sous-catégories (M2M, validées à l'ajout)."""
    step = n // 5  # change à chaque tour des 5 types
    if kind in SECTOR_TYPES:
        sector, subs = refs.sectors[(n + 3 * step) % len(refs.sectors)]
        values = {"secteur": sector, "description_activite": "Activité fictive de démonstration."}
        if kind == AccountType.ENTREPRISE:
            forms = list(LegalForm.values)
            values["forme_juridique"] = forms[step % len(forms)]
            values["rccm"] = f"RCCM-DEMO-{i:04d}"
        return values, _pick(subs, n, 1 + n % 3)
    if kind == AccountType.PRESTATAIRE_SERVICE:
        category = refs.service_categories[step % len(refs.service_categories)]
        values = {
            "categorie_service": category,
            "cni_verifiee": step % 2 == 0,
        }
        if category.code == OTHER_CODE:
            values["categorie_service_libre"] = "Service imaginaire de démonstration"
        return values, []
    code = STRUCTURE_CODES[step % len(STRUCTURE_CODES)]
    values = {"structure_type": refs.structure_types[code]}
    if code == "supermarche":
        values["rayons"] = _pick(list(Aisle.values), n, 1 + n % 3)
    elif code == "restaurant":
        cuisines = list(Cuisine.values)
        values.update(
            cuisine=cuisines[step % len(cuisines)], livraison=step % 2 == 0, horaires=HORAIRES,
        )
    elif code == "hotel":
        standings = list(Standing.values)
        values.update(
            standing=standings[step % len(standings)], nombre_chambres=5 + n % 40,
            equipements=_pick(list(Amenity.values), n, 1 + n % 4),
        )
    elif code == "sante":
        values.update(
            numero_agrement=f"AGREMENT-DEMO-{i:04d}",
            specialites=_pick(list(Speciality.values), n, 1 + n % 3),
        )
    else:
        values["structure_type_libre"] = "Établissement imaginaire de démonstration"
    return values, []


def demo_profile_values(i: int, refs: Referentials) -> tuple[dict, list]:
    """Valeurs (sans propriétaire ni photos) du commerce n° `i` (base 1) + sous-catégories."""
    n = i - 1
    kind = TYPE_ROTATION[n % 5]
    status, reason = demo_status(n)
    values = {
        "type_compte": kind,
        "name": f"{DEMO_PREFIX}{TYPE_LABELS[kind]} {i:02d}",
        "zone": refs.zones[(n + n // 5) % len(refs.zones)],
        "repere": "Repère fictif de démonstration",
        "description": DESCRIPTION,
        "representant_nom": f"{OWNER_PREFIX}{i:02d}",
        "phone_anchor": demo_phone(i),
        "whatsapp_available": n % 4 != 0,
        "status": status,
        "motif_rejet": reason,
    }
    specific, subcategories = _type_values(i, n, kind, refs)
    values.update(specific)
    return values, subcategories


def create_demo_profile(i: int, refs: Referentials) -> tuple[BusinessProfile | None, bool]:
    """Crée le commerce n° `i` s'il n'existe pas. Retourne (profil, créé).

    Clé de reconnaissance : le téléphone fictif du propriétaire. Un commerce déjà là (même
    modifié dans l'admin) n'est jamais réécrit ; un compte de ce téléphone qui a déjà un
    profil quelconque est laissé tel quel.
    """
    phone = demo_phone(i)
    owner = User.objects.filter(phone=phone).first()
    if owner is not None and BusinessProfile.objects.filter(owner=owner).exists():
        return None, False
    values, subcategories = demo_profile_values(i, refs)
    with transaction.atomic():
        if owner is None:
            owner = User.objects.create_user(phone, name=f"{OWNER_PREFIX}{i:02d}")
        values["photo"] = new_key(owner.pk, "photo", JPEG)
        values["representant_photo"] = new_key(owner.pk, "representant_photo", JPEG)
        if values["type_compte"] == AccountType.PRESTATAIRE_SERVICE:
            values["cni_photo"] = new_key(owner.pk, "cni_photo", JPEG)
        profile = BusinessProfile(owner=owner, **values)
        profile.save()  # clean() : le profil est valide par construction
        if subcategories:
            profile.sous_categories.set(subcategories)
    return profile, True


def seed(count: int) -> tuple[int, int]:
    """Crée les commerces 1..count. Retourne (créés, déjà présents)."""
    refs = load_referentials()
    created = existing = 0
    with transaction.atomic():
        for i in range(1, count + 1):
            _, was_created = create_demo_profile(i, refs)
            created += was_created
            existing += not was_created
    return created, existing


def _owner_has_other_data(user_ids: list[int]) -> set[int]:
    """Comptes (parmi `user_ids`) auxquels d'autres données sont rattachées."""
    used: set[int] = set()
    for rel in User._meta.related_objects:
        if rel.related_model is BusinessProfile:
            continue
        field = rel.field
        if rel.many_to_many:
            continue
        model = rel.related_model
        used.update(
            model._base_manager.filter(**{f"{field.name}__in": user_ids})
            .values_list(field.name, flat=True)
        )
    for through in (User.groups.through, User.user_permissions.through):
        used.update(through.objects.filter(user_id__in=user_ids).values_list("user_id", flat=True))
    return used


@transaction.atomic
def flush() -> tuple[int, int]:
    """Supprime UNIQUEMENT les données de démonstration. Retourne (profils, comptes) supprimés.

    Profil : nom au préfixe `[DÉMO] ` ET propriétaire dans le bloc de téléphones réservé.
    Compte : propriétaire d'un tel profil, dans le bloc réservé, nommé « Responsable Démo … »,
    ni administrateur ni équipe, sans aucune autre donnée rattachée (sinon il est conservé)."""
    profiles = BusinessProfile.objects.filter(
        name__startswith=DEMO_PREFIX, owner__phone__regex=PHONE_BLOCK_REGEX
    )
    owner_ids = list(profiles.values_list("owner_id", flat=True))
    profile_count = profiles.count()
    profiles.delete()
    candidates = list(
        User.objects.filter(
            pk__in=owner_ids, phone__regex=PHONE_BLOCK_REGEX, name__startswith=OWNER_PREFIX,
            is_admin=False, is_staff=False, is_superuser=False,
        ).values_list("pk", flat=True)
    )
    keep = _owner_has_other_data(candidates) if candidates else set()
    deletable = [pk for pk in candidates if pk not in keep]
    User.objects.filter(pk__in=deletable).delete()
    return profile_count, len(deletable)
