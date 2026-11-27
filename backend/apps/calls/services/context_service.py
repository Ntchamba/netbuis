"""Fiche de l'appel en cours pour l'agent qui a décroché (D-30, T132b, zone sensible).

C'est l'UNIQUE endroit de l'API qui renvoie le numéro d'un commerce et celui de l'appelant :
- seulement à l'agent qui a répondu (`session.agent`), tant que la session est `answered` ;
- chaque lecture est comptée sur la session (`context_views`, `context_viewed_at`) et notée
  dans le journal serveur SANS numéro ;
- la route répond `Cache-Control: no-store`.
Un autre agent, ou un appel qui n'est pas en cours, ne reçoit jamais de numéro.
"""
import logging

from django.db import transaction
from django.db.models import F
from django.utils import timezone
from rest_framework import status

from apps.admin_panel.models import AuditAction
from apps.admin_panel.services import account_service, audit_service
from apps.business.models import AccountType
from apps.business.services import subscription as subscription_service
from apps.business.services.storage_service import StorageError, get_storage
from apps.calls.models import CallSession, SessionState
from apps.calls.services import events
from apps.calls.services.call_service import CallRefused

logger = logging.getLogger(__name__)

PARTICULIERS = (AccountType.PARTICULIER_VENDEUR, AccountType.PRESTATAIRE_SERVICE)


def _public_url(key: str):
    if not key:
        return None
    try:
        return get_storage().public_url(key)
    except StorageError:
        return None


def _category(profile) -> str | None:
    for relation in (profile.secteur, profile.categorie_service, profile.structure_type):
        if relation is not None:
            return relation.name
    return profile.secteur_libre or profile.categorie_service_libre or (
        profile.structure_type_libre or None)


def _business_card(profile) -> dict:
    now = timezone.now()
    subscription = subscription_service.active_subscription_queryset(now).filter(
        profile=profile).order_by("-end").first()
    zone = profile.zone
    reports = profile.reports.count()
    whatsapp_reports = profile.whatsapp_reports.count()
    return {
        "id": profile.pk,
        "name": profile.name,
        "type_compte": profile.type_compte,
        "type_label": profile.get_type_compte_display(),
        "kind": "particulier" if profile.type_compte in PARTICULIERS else "entreprise",
        "phone": profile.phone_anchor,
        "owner_name": (profile.owner.name or "").strip(),
        "category": _category(profile),
        "sous_categories": list(profile.sous_categories.values_list("name", flat=True)),
        "zone_name": zone.name,
        "zone_parent_name": zone.parent.name if zone.parent_id else None,
        "repere": profile.repere,
        "description": profile.description or profile.description_activite,
        "representant_nom": profile.representant_nom,
        "forme_juridique": profile.get_forme_juridique_display() if profile.forme_juridique else "",
        "rccm": profile.rccm,
        "photo_url": _public_url(profile.photo),
        "representant_photo_url": _public_url(profile.representant_photo),
        "status": profile.status,
        "cni_verifiee": profile.cni_verifiee,
        "motif_rejet": profile.motif_rejet,
        "subscription": {"active": subscription is not None,
                         "end": subscription.end if subscription else None},
        "reports_count": reports,
        "whatsapp_reports_count": whatsapp_reports,
        "calls_count": profile.calls_count,
        "views_count": profile.views_count,
        "created_at": profile.created_at,
        "history": [
            {"action": e.action, "label": e.get_action_display(), "reason": e.reason,
             "admin_name": e.admin.name, "created_at": e.created_at}
            for e in account_service.status_history(profile.owner)
        ],
    }


@transaction.atomic
def read_context(agent, session_id) -> dict:
    """Renvoie la fiche de l'appel à l'agent qui a répondu, et trace la lecture."""
    # Un autre agent (ou un appel inconnu) : 404, comme si la session n'existait pas.
    session = CallSession.objects.select_related("caller", "business__zone__parent",
                                                 "business__owner").filter(
        pk=session_id, agent=agent).first()
    if session is None:
        raise CallRefused("not_found", "Introuvable.", status.HTTP_404_NOT_FOUND)
    # Mise à jour conditionnelle : refuse si l'appel vient de se terminer.
    traced = CallSession.objects.filter(
        pk=session.pk, agent=agent, state=SessionState.ANSWERED
    ).update(context_views=F("context_views") + 1, context_viewed_at=timezone.now())
    if not traced:
        raise CallRefused(
            "call_not_answered", "Cet appel n'est pas en cours.", status.HTTP_409_CONFLICT)
    # La carte est construite avant l'audit : un échec annule tout, aucun numéro ne sort sans trace.
    context = {
        "session_id": session.pk,
        "state": SessionState.ANSWERED,
        "caller": {"name": events.caller_display_name(session.caller),
                   "phone": session.caller.phone},
        "business": _business_card(session.business) if session.business_id else None,
    }
    audit_service.record_action(
        agent, AuditAction.CONSULTATION_NUMERO, session.caller, "Fiche d'appel en cours")
    logger.info("Appel %s : fiche lue par l'agent %s.", session.pk, agent.pk)
    return context
