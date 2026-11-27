"""Historique de l'appelant : ses sessions d'appel et ses liens WhatsApp, du plus récent au plus
ancien. Aucun numéro, aucune salle, aucun jeton."""
from apps.calls.models import CallLog, CallSession

MAX_ROWS_PER_SOURCE = 200


def _business_part(profile) -> dict:
    if profile is None:
        return {"business_id": None, "business_name": None, "zone": None}
    return {"business_id": profile.pk, "business_name": profile.name,
            "zone": profile.zone.name if profile.zone_id else None}


def caller_history(user) -> list[dict]:
    sessions = (
        CallSession.objects.filter(caller=user).select_related("business__zone")
        .order_by("-created_at", "-id")[:MAX_ROWS_PER_SOURCE]
    )
    logs = (
        CallLog.objects.filter(caller=user).select_related("profile__zone", "feedback")
        .order_by("-created_at", "-id")[:MAX_ROWS_PER_SOURCE]
    )
    rows = [
        {"id": None, "session_id": s.id, "type": "call", "state": s.state, "date": s.created_at,
         "feedback": None, **_business_part(s.business)}
        for s in sessions
    ]
    for log in logs:
        feedback = getattr(log, "feedback", None)
        rows.append({
            "id": log.pk, "session_id": None, "type": log.channel, "state": None,
            "date": log.created_at, "feedback": feedback.outcome if feedback else None,
            **_business_part(log.profile),
        })
    rows.sort(key=lambda row: row["date"], reverse=True)
    return rows
