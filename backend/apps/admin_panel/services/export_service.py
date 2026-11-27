"""Export CSV des comptes (T074, zone sensible : revue ligne par ligne).

Colonnes : identifiant, nom, téléphone MASQUÉ, type, statut, langue, administrateur, commerce,
statut du dossier, zone, date de création. JAMAIS : numéro complet (le numéro d'un compte ne
sort que de l'écran détail, audité, et de `POST /api/calls/initiate/`), CNI, pièces, jetons,
mot de passe. Chaque export est audité (`export_comptes`).
Les cellules texte qui commencent par = + - @ (ou tabulation / retour chariot) sont
préfixées d'une apostrophe : un tableur ne les exécute pas comme une formule.
"""
import csv

from django.db import transaction

from apps.admin_panel.models import AuditAction
from apps.admin_panel.serializers.account import masked
from apps.admin_panel.services import account_service, audit_service

HEADER = [
    "id", "nom", "telephone_masque", "type", "statut", "langue", "administrateur",
    "commerce", "statut_dossier", "zone", "cree_le",
]
_DANGEROUS = ("=", "+", "-", "@", "\t", "\r")


def safe_cell(value) -> str:
    text = "" if value is None else str(value)
    if text.startswith(_DANGEROUS):
        return "'" + text
    return text


def _masked_for_csv(user) -> str:
    # « +237 6•• •• •• 41 » commence par « + » : on retire le signe pour ne pas avoir à le
    # neutraliser comme une formule.
    return masked(user).lstrip("+")


def row(user) -> list[str]:
    profile = user.business_profile_or_none
    cells = [
        user.pk, user.name, _masked_for_csv(user),
        "business" if profile else "simple",
        account_service.account_status(user), user.language, "oui" if user.is_admin else "non",
        profile.name if profile else "", profile.status if profile else "",
        profile.zone.name if profile else "", user.created_at.isoformat(),
    ]
    return [safe_cell(c) for c in cells]


class _Echo:
    def write(self, value):
        return value


def start_export(admin):
    """Écrit l'audit puis renvoie (nombre de lignes, itérateur de lignes CSV en texte)."""
    qs = account_service.base_queryset()
    with transaction.atomic():
        count = qs.count()
        audit_service.record_action(
            admin, AuditAction.EXPORT_COMPTES, admin,
            f"accounts.csv : {count} lignes, numéros masqués",
        )
    writer = csv.writer(_Echo(), lineterminator="\r\n")

    def lines():
        yield "﻿" + writer.writerow(HEADER)
        for user in qs.iterator(chunk_size=500):
            yield writer.writerow(row(user))

    return count, lines()
