"""Réglages de plateforme vus par l'administration (T074, zone sensible).

Lecture et écriture réservées à l'Administrateur complet (permission vérifiée par la vue).
Le modèle et les défauts viennent de `apps.core` (non modifié) ; les BORNES hautes sont
déclarées ICI (le modèle n'impose que le minimum 1). L'écriture et l'audit
`modification_reglage` sont dans UNE transaction ; le journal contient la clé, l'ancienne et
la nouvelle valeur (des entiers : aucun secret).
"""
from django.db import transaction
from rest_framework import status

from apps.admin_panel.models import AuditAction
from apps.admin_panel.services import audit_service
from apps.core.exceptions import ApiError
from apps.core.models.platform_setting import (
    DEFAULTS,
    MIN_VALUE,
    PlatformSetting,
    SettingKey,
    UnknownSettingError,
)

# Bornes hautes raisonnables (le minimum est MIN_VALUE = 1 : 0 n'a pas de sens, voir core).
MAX_VALUES: dict[str, int] = {
    SettingKey.PLAFOND_SOUS_CATEGORIES_NON_ABONNE: 50,
    SettingKey.PLAFOND_PUBLICATIONS_NON_ABONNE: 1000,
    SettingKey.LIMITE_APPELS_PAR_MINUTE: 60,
    SettingKey.LIMITE_APPELS_PAR_JOUR: 1000,
    SettingKey.SEUIL_APPELS_ABONNEMENT: 1000,
    SettingKey.TRENDS_MIN_SEARCHES: 1000,
    SettingKey.TRENDS_MIN_ACCOUNTS: 1000,
    SettingKey.TRENDS_WINDOW_DAYS: 90,
}


class UnknownSetting(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "unknown_setting"
    default_detail = "Réglage inconnu."


class InvalidSettingValue(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "invalid_value"
    default_detail = "Valeur incorrecte."


def check_key(key: str) -> str:
    if key not in SettingKey.values:
        raise UnknownSetting(str(UnknownSettingError(key)))
    return key


def check_value(key: str, value) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise InvalidSettingValue("La valeur doit être un nombre entier.")
    high = MAX_VALUES[key]
    if not MIN_VALUE <= value <= high:
        raise InvalidSettingValue(f"La valeur doit être comprise entre {MIN_VALUE} et {high}.")
    return value


def list_settings() -> list[dict]:
    """Les réglages, dans l'ordre de `SettingKey`, valeur courante lue en base."""
    rows = {s.key: s for s in PlatformSetting.objects.select_related("modified_by")}
    out = []
    for key in SettingKey.values:
        row = rows.get(key)
        out.append(_describe(key, row))
    return out


def _describe(key: str, row: PlatformSetting | None) -> dict:
    return {
        "key": key,
        "label": SettingKey(key).label,
        "value": row.value if row else DEFAULTS[key],
        "default": DEFAULTS[key],
        "min": MIN_VALUE,
        "max": MAX_VALUES[key],
        "modified_by": row.modified_by_id if row else None,
        "updated_at": row.updated_at if row else None,
    }


@transaction.atomic
def update_setting(admin, key: str, value, note: str = "") -> dict:
    check_key(key)
    value = check_value(key, value)
    row = PlatformSetting.objects.select_for_update().filter(key=key).first()
    old = row.value if row else DEFAULTS[key]
    if old == value:  # aucun changement : rien à écrire ni à auditer
        return _describe(key, row)
    if row is None:
        row = PlatformSetting(key=key)
    row.value = value
    row.modified_by = admin
    row.save()
    reason = f"{key} : {old} -> {value}"
    note = (note or "").strip()
    if note:
        reason = f"{reason} ; motif : {note}"
    audit_service.record_action(admin, AuditAction.MODIFICATION_REGLAGE, row, reason)
    return _describe(key, row)
