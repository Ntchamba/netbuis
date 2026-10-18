"""Création et modification du compte business (T026) — règles du serveur.

Contrat des plafonds : `sous_categories`, `rayons` et `specialites` sont limités à
`plafond_sous_categories_non_abonne` (3 par défaut, D-12) sans abonnement actif (`is_subscribed`).
La 4ᵉ est refusée avec le code `SUBSCRIPTION_REQUIRED`. Une requête qui ne fait que retirer des
éléments ou renvoyer ceux que le profil a déjà n'est pas plafonnée : un abonnement échu ne
supprime rien et ne bloque pas la modification du reste.

Règle D-08 (profil `actif`) : changer réellement `name`, `type_compte`, `zone` ou `phone_anchor`
le remet en `en_attente_validation` ; description, photos, repère… non. Un profil `rejete` qui
reçoit une modification réussie repart en `en_attente_validation`, `motif_rejet` effacé.

Tout est fait dans une transaction ; les erreurs du modèle (`clean()`, signal des
sous-catégories) deviennent des 400 `{code: "invalid", fields}` en français.
"""
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError, transaction
from rest_framework import status
from rest_framework.exceptions import ValidationError

from apps.business.models import (
    BusinessProfile,
    BusinessStatus,
    validate_subcategories,
)
from apps.business.models.profile import ALL_STRUCTURE_DETAIL_FIELDS, AccountType
from apps.business.services.subscription import is_subscribed
from apps.catalog.models import Subcategory
from apps.core.exceptions import ApiError
from apps.core.services.settings_service import get_setting

CAP_SETTING = "plafond_sous_categories_non_abonne"
CAPPED_LISTS = {  # champ -> nom affiché dans le message
    "sous_categories": "sous-catégories",
    "rayons": "rayons",
    "specialites": "spécialités",
}
# Champs dont un vrai changement renvoie un profil actif en validation (D-08).
# Jamais pris du client, même si un appelant les glisse dans `data`.
SERVER_FIELDS = (
    "owner", "status", "motif_rejet", "cni_verifiee", "calls_count", "views_count", "id", "pk",
)
SENSITIVE_FIELDS = ("name", "type_compte", "zone", "phone_anchor")


class BusinessExists(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "business_exists"
    default_detail = "Vous avez déjà un compte business."


class NoBusiness(ApiError):
    status_code = status.HTTP_404_NOT_FOUND
    default_code = "no_business"
    default_detail = "Vous n'avez pas encore de compte business."


class SubscriptionRequired(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "SUBSCRIPTION_REQUIRED"
    default_detail = "Abonnez-vous pour dépasser la limite."


def get_own_profile(user) -> BusinessProfile:
    """Le compte business de `user` ; NoBusiness (404) s'il n'en a pas."""
    profile = (
        BusinessProfile.objects.filter(owner=user)
        .select_related("zone", "secteur", "categorie_service", "structure_type")
        .first()
    )
    if profile is None:
        raise NoBusiness()
    return profile


def _drf_errors(exc: DjangoValidationError) -> ValidationError:
    if hasattr(exc, "error_dict"):
        return ValidationError(exc.message_dict)
    return ValidationError({"non_field_errors": exc.messages})


def _structure_detail_errors(profile: BusinessProfile) -> dict[str, str]:
    """Détails exigés par type de structure (règles de l'API, en plus de `clean()`).
    Seul le numéro d'agrément sanitaire est facultatif dans la spec."""
    if profile.type_compte != AccountType.STRUCTURE or profile.structure_type_id is None:
        return {}
    errors = {}
    code = profile.structure_type.code
    if code == "supermarche" and not profile.rayons:
        errors["rayons"] = "Choisissez au moins un rayon."
    elif code == "restaurant":
        if not profile.cuisine:
            errors["cuisine"] = "Choisissez le type de cuisine."
        if profile.livraison is None:
            errors["livraison"] = "Indiquez si vous livrez."
    elif code == "hotel" and not profile.standing:
        errors["standing"] = "Choisissez le standing."
    elif code == "sante" and not profile.specialites:
        errors["specialites"] = "Choisissez au moins une spécialité."
    return errors


def _check_caps(profile: BusinessProfile, data: dict, current: dict) -> None:
    """Plafond sur les listes envoyées. `current` : valeurs actuelles (profil existant)."""
    sent = [name for name in CAPPED_LISTS if name in data]
    if not sent:
        return
    cap = get_setting(CAP_SETTING)
    if all(len(data[name]) <= cap for name in sent) or is_subscribed(profile):
        return
    for name in sent:
        values = list(data[name])
        if len(values) > cap and not set(values) <= set(current.get(name, [])):
            raise SubscriptionRequired(
                f"Abonnez-vous pour choisir plus de {cap} {CAPPED_LISTS[name]}."
            )


def _changed_sensitive(profile: BusinessProfile, data: dict) -> bool:
    for name in SENSITIVE_FIELDS:
        if name not in data:
            continue
        old = profile.zone_id if name == "zone" else getattr(profile, name)
        new = data[name].pk if name == "zone" else data[name]
        if old != new:
            return True
    return False


def create_profile(owner, data: dict) -> BusinessProfile:
    """Crée le compte business de `owner` en `en_attente_validation`.
    `data` : valeurs déjà nettoyées par le sérialiseur (sans owner ni status)."""
    data = {k: v for k, v in data.items() if k not in SERVER_FIELDS}
    subcategories = list(data.pop("sous_categories", []))
    profile = BusinessProfile(owner=owner, status=BusinessStatus.PENDING, **data)
    try:
        with transaction.atomic():
            if BusinessProfile.objects.filter(owner=owner).exists():
                raise BusinessExists()
            profile.clean()
            errors = _structure_detail_errors(profile)
            if errors:
                raise ValidationError(errors)
            validate_subcategories(profile, subcategories)
            _check_caps(profile, {**data, "sous_categories": subcategories}, {})
            profile.save()
            profile.sous_categories.set(subcategories)
    except DjangoValidationError as exc:
        raise _drf_errors(exc) from exc
    except IntegrityError as exc:  # deux créations en même temps pour le même compte
        if BusinessProfile.objects.filter(owner=owner).exists():
            raise BusinessExists() from exc
        raise
    return profile


def update_profile(profile: BusinessProfile, data: dict) -> BusinessProfile:
    """Applique un PATCH (valeurs nettoyées) selon D-08 et la correction d'un rejet."""
    data = {k: v for k, v in data.items() if k not in SERVER_FIELDS}
    if not data:
        return profile
    try:
        with transaction.atomic():
            profile = BusinessProfile.objects.select_for_update().get(pk=profile.pk)
            current = {
                "sous_categories": list(profile.sous_categories.values_list("pk", flat=True)),
                "rayons": list(profile.rayons), "specialites": list(profile.specialites),
            }
            sensitive = _changed_sensitive(profile, data)
            subcategories = data.pop("sous_categories", None)
            if subcategories is not None:
                subcategories = [sub.pk for sub in subcategories]
            for name, value in data.items():
                setattr(profile, name, value)
            if profile.status == BusinessStatus.REJECTED:
                profile.status, profile.motif_rejet = BusinessStatus.PENDING, ""
            elif profile.status == BusinessStatus.ACTIVE and sensitive:
                profile.status = BusinessStatus.PENDING
            profile.clean()
            touched = {"type_compte", "structure_type", *ALL_STRUCTURE_DETAIL_FIELDS}
            errors = _structure_detail_errors(profile) if touched & set(data) else {}
            if errors:
                raise ValidationError(errors)
            # Les sous-catégories finales doivent coller au type et au secteur finaux.
            final_subs = (
                current["sous_categories"] if subcategories is None else subcategories
            )
            validate_subcategories(profile, Subcategory.objects.filter(pk__in=final_subs))
            checked = {k: v for k, v in data.items() if k in CAPPED_LISTS}
            if subcategories is not None:
                checked["sous_categories"] = subcategories
            _check_caps(profile, checked, current)
            profile.save()
            if subcategories is not None:
                profile.sous_categories.set(subcategories)
    except DjangoValidationError as exc:
        raise _drf_errors(exc) from exc
    return profile
