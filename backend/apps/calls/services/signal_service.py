"""Signalisation WebRTC entre l'appelant et l'agent (D-31, docs/spec/APPELS_WEBRTC.md).

Un signal est relayé à l'AUTRE partie seulement. Le message NOTIFY ne porte que des
identifiants (`session_id`, `signal_id`) : le flux SSE du destinataire relit la ligne en base,
ce qui évite la limite de ~8 000 octets de `pg_notify` et garde le contenu hors du canal
partagé. Rien du contenu (SDP, candidats) n'est écrit dans un journal.
Les signaux sont supprimés à la fin de la session (`session_service._finish`).
"""
import json
import logging

from django.db import transaction
from django.utils import timezone
from rest_framework import status

from apps.calls.models import (
    MAX_SIGNAL_BYTES,
    MAX_SIGNALS_PER_SESSION,
    CallSession,
    CallSignal,
    SessionState,
    SignalRole,
)
from apps.calls.services import events, webrtc
from apps.calls.services.call_service import CallRefused

logger = logging.getLogger(__name__)

SIGNAL = "signal"


def _refused(code: str, message: str, http_status: int) -> CallRefused:
    return CallRefused(code, message, http_status)


def serialize(signal: CallSignal) -> dict:
    return {"id": signal.pk, "type": signal.kind, "data": signal.data}


def send(role: str, user, session_id, kind: str, data: dict) -> CallSignal:
    """Enregistre le signal et le publie pour l'autre partie."""
    if not webrtc.is_webrtc():
        raise _refused("webrtc_not_enabled", "Ce mode d'appel n'est pas activé.",
                       status.HTTP_409_CONFLICT)
    if len(json.dumps(data, separators=(",", ":")).encode()) > MAX_SIGNAL_BYTES:
        raise _refused("signal_too_large", "Signal trop volumineux.",
                       status.HTTP_413_REQUEST_ENTITY_TOO_LARGE)
    now = timezone.now()
    with transaction.atomic():
        # Verrou de la session : sérialise le décompte, la fin d'appel et la réponse de l'agent.
        rows = CallSession.objects.select_for_update().filter(pk=session_id)
        session = (rows.filter(caller=user) if role == SignalRole.CALLER
                   else rows.filter(agent=user)).first()
        if session is None:
            raise _refused("not_found", "Introuvable.", status.HTTP_404_NOT_FOUND)
        allowed = (
            (SessionState.RINGING, SessionState.ANSWERED) if role == SignalRole.CALLER
            else (SessionState.ANSWERED,)
        )
        if session.state not in allowed or (
            session.state == SessionState.RINGING
            and session.expires_at is not None and session.expires_at <= now
        ):
            raise _refused("call_not_active", "Cet appel n'accepte plus de signaux.",
                           status.HTTP_409_CONFLICT)
        if CallSignal.objects.filter(session=session).count() >= MAX_SIGNALS_PER_SESSION:
            raise _refused("signal_quota_exceeded", "Trop de signaux pour cet appel.",
                           status.HTTP_429_TOO_MANY_REQUESTS)
        signal = CallSignal.objects.create(
            session=session, from_role=role, kind=kind, data=data)
        events.publish(SIGNAL, {"session_id": str(session.pk), "signal_id": signal.pk})
    return signal


def stream_payload(signal: CallSignal) -> dict:
    """Événement SSE `signal`. `signal_id` est unique : le client ignore un doublon."""
    return {"session_id": str(signal.session_id), "signal_id": signal.pk,
            "type": signal.kind, "data": signal.data}


def pending_for_agent(session_id) -> list[dict]:
    """Signaux de l'appelant déjà reçus (sonnerie), rendus dans la réponse de `accept`."""
    rows = CallSignal.objects.filter(session_id=session_id, from_role=SignalRole.CALLER)
    return [serialize(s) for s in rows.order_by("id")]


def pending_for_caller(session_id, user_id) -> list[dict]:
    """Signaux de l'agent déjà publiés, rejoués à l'ouverture du flux de l'appelant (la
    réponse a pu partir avant que le flux soit ouvert)."""
    rows = CallSignal.objects.filter(
        session_id=session_id, session__caller_id=user_id, from_role=SignalRole.AGENT
    ).order_by("id")
    return [stream_payload(s) for s in rows]


def for_recipient(signal_id: int, role: str, user_id: int) -> dict | None:
    """Contenu d'un signal pour son DESTINATAIRE (`role` = rôle de celui qui lit), sinon None."""
    signal = CallSignal.objects.select_related("session").filter(pk=signal_id).first()
    if signal is None or signal.from_role == role:
        return None
    session = signal.session
    owner = session.caller_id if role == SignalRole.CALLER else session.agent_id
    if owner != user_id:
        return None
    return stream_payload(signal)
