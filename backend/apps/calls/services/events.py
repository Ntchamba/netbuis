"""Événements d'appel poussés en temps réel par PostgreSQL `LISTEN/NOTIFY` (D-25, D-26).

`publish` est appelé DANS la transaction qui change l'état de la session : PostgreSQL ne
délivre la notification qu'au commit (jamais d'événement pour un état annulé) et l'ordre des
événements suit l'ordre des commits. Fonctionne avec plusieurs processus, sans autre service.

Le contenu ne porte JAMAIS le nom de la salle, un jeton Jitsi ni un numéro de téléphone.
"""
import json

from django.db import connection

CHANNEL = "netbuis_calls"

RINGING = "ringing"
TAKEN = "taken"
ENDED = "ended"
MISSED = "missed"
DECLINED = "declined"
CANCELLED = "cancelled"


def caller_display_name(user) -> str:
    """Nom d'affichage (jamais le numéro)."""
    return (user.name or "").strip()[:60] or "Utilisateur"


def publish(event: str, payload: dict) -> None:
    body = json.dumps({"event": event, **payload}, separators=(",", ":"), ensure_ascii=False)
    with connection.cursor() as cursor:
        cursor.execute("SELECT pg_notify(%s, %s)", [CHANNEL, body])


def state_payload(session, reason: str = "") -> dict:
    return {
        "session_id": str(session.id),
        "state": session.state,
        "reason": reason or session.end_reason,
    }


def ringing_payload(session, ring_seconds_left: int | None = None) -> dict:
    """Ce que voit un agent : appelant (prénom/nom), commerce concerné, échéance."""
    business = session.business
    return {
        "session_id": str(session.id),
        "state": session.state,
        "caller_name": caller_display_name(session.caller),
        "business": {"id": business.pk, "name": business.name} if business else None,
        "expires_at": session.expires_at.isoformat() if session.expires_at else None,
        "ring_seconds_left": ring_seconds_left,
    }
