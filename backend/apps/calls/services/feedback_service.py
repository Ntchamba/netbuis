"""Retours d'appel et signalements « pas de WhatsApp » (masquage à 3 comptes distincts)."""
from django.db import transaction
from rest_framework import status

from apps.business.models import BusinessProfile
from apps.calls.models import CallChannel, CallFeedback, CallLog, WhatsAppReport
from apps.calls.services.call_service import CallRefused

# Nombre de comptes distincts qui désactivent WhatsApp pour un commerce.
WHATSAPP_REPORT_THRESHOLD = 3


def _not_found() -> CallRefused:
    return CallRefused("not_found", "Introuvable.", status.HTTP_404_NOT_FOUND)


def save_feedback(user, call_id: int, outcome: str) -> CallFeedback:
    """Seul l'appelant propriétaire répond (404 sinon, pour ne pas révéler l'appel).
    Le retour est modifiable : un nouveau choix remplace le précédent."""
    log = CallLog.objects.filter(pk=call_id, caller=user).first()
    if log is None:
        raise _not_found()
    feedback, _ = CallFeedback.objects.update_or_create(call=log, defaults={"outcome": outcome})
    return feedback


def report_no_whatsapp(user, business_id: int) -> bool:
    """Enregistre le signalement ; renvoie True si WhatsApp vient d'être désactivé.

    Il faut avoir reçu le lien WhatsApp de ce commerce (un CallLog `whatsapp`) : cela évite
    les signalements sans contact réel. Un compte ne compte qu'une fois par commerce.
    """
    with transaction.atomic():
        profile = BusinessProfile.objects.select_for_update().filter(pk=business_id).first()
        if profile is None or not CallLog.objects.filter(
            caller=user, profile=profile, channel=CallChannel.WHATSAPP
        ).exists():
            raise _not_found()
        WhatsAppReport.objects.get_or_create(reporter=user, profile=profile)
        distinct = (
            WhatsAppReport.objects.filter(profile=profile, reviewed=False)
            .values("reporter").distinct().count()
        )
        if distinct >= WHATSAPP_REPORT_THRESHOLD and profile.whatsapp_available:
            # Seul champ écrit sur le profil (autorisation exceptionnelle de T051).
            BusinessProfile.objects.filter(pk=profile.pk).update(whatsapp_available=False)
            return True
    return False
