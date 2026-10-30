"""Référentiels modifiables par l'administration (T074b, zone sensible).

Zones, secteurs, sous-catégories, catégories de service, types de structure, produits du
catalogue et synonymes : liste, création, modification, DÉSACTIVATION / RÉACTIVATION. Il n'y a
JAMAIS de suppression physique (les commerces existants gardent leur lien ; une ligne
désactivée disparaît des choix et de la carte, les services publics filtrent `is_active`).

Règles de cohérence (décisions documentées) :
- une zone a un parent du niveau attendu, sans cycle, nom unique sous le même parent (le modèle
  `Zone` le vérifie ; le NIVEAU et le CODE STABLE ne changent plus après la création) ;
- désactiver un parent qui a encore des enfants ACTIFS est refusé : 409 `has_active_children`
  (on ne désactive pas en cascade : l'administrateur choisit en connaissance de cause) ;
- on ne crée pas et on ne réactive pas une zone / sous-catégorie sous un parent désactivé :
  409 `parent_inactive` ;
- la ligne « Autre » (code `autre`) des secteurs, catégories de service et types de structure
  n'est pas désactivable (les valeurs libres des commerçants en dépendent) : 409
  `protected_item` ;
- création et modification écrivent l'objet ET l'audit dans UNE transaction ; l'audit contient
  « champ : ancien -> nouveau » (jamais de secret ni de numéro).

Les modèles de geo et catalog ne sont pas modifiés ; seuls leurs champs existants sont écrits.
"""
from collections import Counter
from dataclasses import dataclass

from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError, models, transaction
from django.db.models import Count, Q
from rest_framework import status
from rest_framework.exceptions import NotFound, ValidationError

from apps.admin_panel.models import AuditAction
from apps.admin_panel.services import audit_service
from apps.business.models import BusinessProfile
from apps.catalog.models import (
    CatalogProduct,
    Sector,
    ServiceCategory,
    StructureType,
    Subcategory,
    Synonym,
)
from apps.core.exceptions import ApiError
from apps.core.utils.text_normalize import normalize_text
from apps.geo.models import Zone

OTHER_CODE = "autre"
MAX_AUDIT_TEXT = 900  # le journal accepte 1000 caractères
FREE_VALUES_LIMIT = 100


class AlreadyExists(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "already_exists"
    default_detail = "Cet élément existe déjà."


class HasActiveChildren(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "has_active_children"
    default_detail = "Désactivez d'abord les éléments actifs rattachés."


class ParentInactive(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "parent_inactive"
    default_detail = "Le parent est désactivé : réactivez-le d'abord."


class ProtectedItem(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "protected_item"
    default_detail = "La ligne « Autre » ne peut pas être désactivée."


class InvalidState(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "invalid_state"
    default_detail = "L'élément est déjà dans cet état."


@dataclass(frozen=True)
class Kind:
    slug: str
    model: type[models.Model]
    label: str
    create_fields: tuple[str, ...]
    update_fields: tuple[str, ...]
    parent_field: str | None = None  # FK dont l'état actif conditionne la création/réactivation
    has_active: bool = True
    children_related: str | None = None  # relation inverse comptée pour `has_active_children`
    code_protected: bool = False  # la ligne `autre` est protégée


_ITEM = ("name", "icon", "order")
KINDS: dict[str, Kind] = {
    k.slug: k
    for k in (
        Kind("zones", Zone, "zone",
             ("name", "level", "parent", "official_code", "order", "latitude", "longitude"),
             ("name", "parent", "official_code", "order", "latitude", "longitude"),
             parent_field="parent", children_related="children"),
        Kind("sectors", Sector, "secteur", ("code", *_ITEM), _ITEM,
             children_related="subcategories", code_protected=True),
        Kind("subcategories", Subcategory, "sous-catégorie", ("sector", "code", *_ITEM), _ITEM,
             parent_field="sector"),
        Kind("service-categories", ServiceCategory, "catégorie de service",
             ("code", *_ITEM), _ITEM, code_protected=True),
        Kind("structure-types", StructureType, "type de structure",
             ("code", *_ITEM), _ITEM, code_protected=True),
        Kind("products", CatalogProduct, "produit du catalogue",
             ("name", "category"), ("name", "category")),
        Kind("synonyms", Synonym, "synonyme", ("product", "term"), ("term",)),
    )
}


def get_kind(slug: str) -> Kind:
    return KINDS[slug]


# --- Lecture -----------------------------------------------------------------------


def base_queryset(kind: Kind):
    qs = kind.model.objects.all()
    if kind.slug == "zones":
        qs = qs.select_related("parent").annotate(
            active_children_count=Count("children", filter=Q(children__is_active=True))
        )
    elif kind.slug == "sectors":
        qs = qs.annotate(
            active_children_count=Count(
                "subcategories", filter=Q(subcategories__is_active=True))
        )
    elif kind.slug == "products":
        qs = qs.select_related("category").annotate(synonyms_count=Count("synonyms"))
    elif kind.slug == "synonyms":
        qs = qs.select_related("product")
    return qs


def _bool(value):
    return {"true": True, "1": True, "false": False, "0": False}.get(str(value).lower())


FILTERS = {
    "zones": {"level": "level"},
    "subcategories": {"sector": "sector_id"},
    "products": {"category": "category_id"},
    "synonyms": {"product": "product_id"},
}


def list_queryset(kind: Kind, params):
    """Liste filtrée. Filtres : `is_active`, `q` (nom sans accents), selon le type
    `level`/`parent` (zones), `sector` (sous-catégories), `category` (produits), `product`."""
    qs = base_queryset(kind)
    active = _bool(params.get("is_active", ""))
    if kind.has_active and active is not None:
        qs = qs.filter(is_active=active)
    query = normalize_text(params.get("q", ""))
    if query:
        if kind.slug in ("zones", "products"):
            qs = qs.filter(normalized_name__contains=query)
        elif kind.slug == "synonyms":
            qs = qs.filter(normalized_term__contains=query)
        else:
            qs = qs.filter(name__icontains=params.get("q", "").strip())
    for param, field in FILTERS.get(kind.slug, {}).items():
        value = params.get(param, "")
        if value not in (None, ""):
            qs = qs.filter(**{field: value}) if (param == "level" or str(value).isdigit()) \
                else qs.none()
    if kind.slug == "zones" and params.get("parent"):
        value = params["parent"]
        if value in ("root", "null"):
            qs = qs.filter(parent__isnull=True)
        else:
            qs = qs.filter(parent_id=value) if str(value).isdigit() else qs.none()
    return qs


def get_object(kind: Kind, pk: int, *, lock: bool = False):
    qs = base_queryset(kind)
    if lock:  # verrou sur la seule ligne (les jointures/agrégats l'interdisent)
        obj = kind.model.objects.select_for_update().filter(pk=pk).first()
        if obj is None:
            raise NotFound()
        return obj
    obj = qs.filter(pk=pk).first()
    if obj is None:
        raise NotFound()
    return obj


# --- Écriture ----------------------------------------------------------------------


def _text(value) -> str:
    if isinstance(value, models.Model):
        return f"#{value.pk} {value}"
    return repr(value) if value not in (None, "") else "(vide)"


def _clip(text: str) -> str:
    return text if len(text) <= MAX_AUDIT_TEXT else text[: MAX_AUDIT_TEXT - 1] + "…"


def _check_duplicate(kind: Kind, values: dict, instance=None) -> None:
    model, qs = kind.model, None
    if kind.slug == "zones":
        name = normalize_text(values["name"])
        qs = model.objects.filter(
            level=values["level"], parent=values.get("parent"), normalized_name=name)
    elif kind.slug == "products":
        qs = model.objects.filter(normalized_name=normalize_text(values["name"]))
    elif kind.slug == "synonyms":
        qs = model.objects.filter(
            product=values["product"], normalized_term=normalize_text(values["term"]))
    elif kind.slug == "subcategories":
        qs = model.objects.filter(sector=values["sector"], code=values["code"])
    elif "code" in values:
        qs = model.objects.filter(code=values["code"])
    if qs is not None:
        if instance is not None:
            qs = qs.exclude(pk=instance.pk)
        if qs.exists():
            raise AlreadyExists()


def _save(instance) -> None:
    try:
        with transaction.atomic():
            instance.save()
    except DjangoValidationError as exc:
        detail = exc.message_dict if hasattr(exc, "error_dict") else exc.messages
        raise ValidationError(detail) from exc
    except IntegrityError as exc:
        raise AlreadyExists() from exc


def _require_active_parent(kind: Kind, parent) -> None:
    if kind.parent_field and parent is not None and not parent.is_active:
        raise ParentInactive()


@transaction.atomic
def create(admin, kind: Kind, data: dict):
    values = {f: data[f] for f in kind.create_fields if f in data}
    _check_duplicate(kind, values)
    if kind.parent_field:
        _require_active_parent(kind, values.get(kind.parent_field))
    instance = kind.model(**values)
    _save(instance)
    summary = ", ".join(f"{f} : {_text(v)}" for f, v in values.items())
    audit_service.record_action(
        admin, AuditAction.CREATION_REFERENTIEL, instance,
        _clip(f"{kind.label} créé(e) ; {summary}"),
    )
    return get_object(kind, instance.pk)


@transaction.atomic
def update(admin, kind: Kind, pk: int, data: dict):
    instance = get_object(kind, pk, lock=True)
    changes = {}
    for field in kind.update_fields:
        if field in data and getattr(instance, field) != data[field]:
            changes[field] = (getattr(instance, field), data[field])
    if not changes:
        return get_object(kind, pk)
    candidate = {f: getattr(instance, f) for f in kind.create_fields if hasattr(instance, f)}
    candidate.update({f: new for f, (_, new) in changes.items()})
    _check_duplicate(kind, candidate, instance)
    if "parent" in changes and instance.is_active:
        _require_active_parent(kind, changes["parent"][1])
    for field, (_, new) in changes.items():
        setattr(instance, field, new)
    _save(instance)
    summary = " ; ".join(f"{f} : {_text(o)} -> {_text(n)}" for f, (o, n) in changes.items())
    audit_service.record_action(
        admin, AuditAction.MODIFICATION_REFERENTIEL, instance,
        _clip(f"{kind.label} modifié(e) ; {summary}"),
    )
    return get_object(kind, pk)


@transaction.atomic
def set_active(admin, kind: Kind, pk: int, active: bool, note: str = ""):
    if not kind.has_active:
        raise NotFound()
    instance = get_object(kind, pk, lock=True)
    if instance.is_active == active:
        raise InvalidState()
    if not active:
        if kind.code_protected and getattr(instance, "code", "") == OTHER_CODE:
            raise ProtectedItem()
        if kind.children_related and getattr(instance, kind.children_related).filter(
                is_active=True).exists():
            raise HasActiveChildren()
    elif kind.parent_field:
        _require_active_parent(kind, getattr(instance, kind.parent_field))
    instance.is_active = active
    instance.save(update_fields=["is_active", "updated_at"])
    action = (AuditAction.REACTIVATION_REFERENTIEL if active
              else AuditAction.DESACTIVATION_REFERENTIEL)
    reason = f"{kind.label} : is_active : {not active} -> {active}"
    note = (note or "").strip()
    if note:
        reason = f"{reason} ; motif : {note}"
    audit_service.record_action(admin, action, instance, _clip(reason))
    return get_object(kind, pk)


# --- Valeurs libres à examiner -----------------------------------------------------

FREE_FIELDS = ("secteur_libre", "categorie_service_libre", "structure_type_libre")


def free_values() -> dict[str, list[dict]]:
    """Valeurs libres saisies par les commerçants, regroupées par valeur normalisée, triées
    par fréquence décroissante (puis ordre alphabétique), `FREE_VALUES_LIMIT` au plus par
    champ. Comptes bloqués, supprimés ou inactifs exclus. Aucun numéro ni identifiant de
    personne : seulement la valeur, sa forme normalisée et le nombre de commerces."""
    live = BusinessProfile.objects.filter(
        owner__is_active=True, owner__is_blocked=False, owner__is_deleted=False
    )
    result = {}
    for field in FREE_FIELDS:
        rows = (live.exclude(**{field: ""}).values(field)
                .annotate(total=Count("pk")).values_list(field, "total"))
        counts: Counter = Counter()
        variants: dict[str, Counter] = {}
        for raw, total in rows:
            key = normalize_text(raw)
            if not key:
                continue
            counts[key] += total
            variants.setdefault(key, Counter())[raw.strip()] += total
        ordered = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[:FREE_VALUES_LIMIT]
        result[field] = [
            {"value": sorted(variants[key].items(), key=lambda kv: (-kv[1], kv[0]))[0][0],
             "normalized": key, "count": total}
            for key, total in ordered
        ]
    return result
