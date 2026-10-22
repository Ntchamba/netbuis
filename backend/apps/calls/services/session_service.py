"""Sessions d'appel vers l'équipe NetBuis (zone sensible).

Chemin critique (D-26) : `create_session` fait UNE transaction courte, sans tâche lente
(ni mail, ni calcul) ; l'événement part au commit par `LISTEN/NOTIFY`.

Toutes les transitions d'état sont des `UPDATE … WHERE state = <état attendu>` : un seul
gagnant même si deux requêtes arrivent ensemble. Aucun nom de salle, jeton ni numéro de
téléphone n'est écrit dans un journal.
"""
import logging
from datetime import timedelta

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone
from rest_framework import status

from apps.accounts.models import User
from apps.business.models import BusinessProfile
from apps.calls.models import (
    CallSession,
    CallSessionDecline,
    EndReason,
    SessionState,
)
from apps.calls.services import events, jitsi, presence
from apps.calls.services.call_service import (
    CallRefused,
    account_blocked,
    business_not_active,
)
from apps.calls.services.quota import caller_may_start_call

logger = logging.getLogger(__name__)

TERMINAL_STATES = (
    SessionState.ENDED, SessionState.MISSED, SessionState.DECLINED,
    SessionState.UNAVAILABLE, SessionState.CANCELLED,
)


def _not_found() -> CallRefused:
    return CallRefused("not_found", "Introuvable.", status.HTTP_404_NOT_FOUND)


def _conflict(code: str, message: str, **extra) -> CallRefused:
    return CallRefused(code, message, status.HTTP_409_CONFLICT, extra)


def _display_name(user) -> str:
    return events.caller_display_name(user)


# --- Transitions -------------------------------------------------------------------------


def _finish(session_id, from_state, to_state, reason: str, event: str, now=None) -> bool:
    """Fait passer la session de `from_state` à `to_state` si (et seulement si) elle y est
    encore, puis publie `event`. Vrai si CETTE requête a fait la transition."""
    now = now or timezone.now()
    with transaction.atomic():
        done = CallSession.objects.filter(pk=session_id, state=from_state).update(
            state=to_state, ended_at=now, end_reason=reason
        )
        if done:
            events.publish(event, {"session_id": str(session_id), "state": to_state,
                                   "reason": reason})
    return bool(done)


def expire_stale(now=None, *, caller_id=None, session_id=None) -> int:
    """Sonneries dépassées -> `missed` ; appels « en cours » trop vieux -> `ended`.
    Retourne le nombre de sessions closes. Sûr à lancer par plusieurs processus."""
    now = now or timezone.now()
    ringing = CallSession.objects.filter(state=SessionState.RINGING, expires_at__lte=now)
    stuck = CallSession.objects.filter(
        state=SessionState.ANSWERED,
        answered_at__lte=now - timedelta(seconds=settings.CALL_MAX_DURATION),
    )
    if caller_id is not None:
        ringing, stuck = ringing.filter(caller_id=caller_id), stuck.filter(caller_id=caller_id)
    if session_id is not None:
        ringing, stuck = ringing.filter(pk=session_id), stuck.filter(pk=session_id)
    closed = 0
    for pk in list(ringing.values_list("pk", flat=True)):
        closed += _finish(pk, SessionState.RINGING, SessionState.MISSED, EndReason.TIMEOUT,
                          events.MISSED, now)
    for pk in list(stuck.values_list("pk", flat=True)):
        closed += _finish(pk, SessionState.ANSWERED, SessionState.ENDED, EndReason.TOO_LONG,
                          events.ENDED, now)
    return closed


# --- Côté appelant -----------------------------------------------------------------------


def _join_for_caller(session, user) -> dict:
    return jitsi.build_join(
        session.room, user_id=user.pk, display_name=_display_name(user), moderator=False
    )


def create_session(user, business_id: int | None = None) -> dict:
    """Crée la session. Retourne {"session", "jitsi", "ring_seconds", "unavailable"}."""
    if not user.can_login():
        raise account_blocked()
    jitsi.ensure_configured()  # avant tout effet : ne pas faire sonner des agents pour rien
    now = timezone.now()
    try:
        with transaction.atomic():
            # Verrou de la ligne appelant : sérialise limites et « une seule session active ».
            caller = User.objects.select_for_update().get(pk=user.pk)
            if not caller.can_login():
                raise account_blocked()
            expire_stale(now, caller_id=caller.pk)
            active = CallSession.objects.filter(
                caller=caller, state__in=(SessionState.RINGING, SessionState.ANSWERED)
            ).values_list("pk", flat=True).first()
            if active:
                raise _conflict(
                    "call_already_active", "Vous avez déjà un appel en cours.",
                    session_id=str(active),
                )
            business = None
            if business_id is not None:
                business = BusinessProfile.objects.visible().filter(pk=business_id).first()
                if business is None:
                    raise business_not_active()
            billing = caller_may_start_call(caller, now)
            room = jitsi.new_room_name()
            if not presence.has_available_agent(now):
                session = CallSession.objects.create(
                    caller=caller, business=business, room=room, billing_type=billing,
                    state=SessionState.UNAVAILABLE, end_reason=EndReason.NO_AGENT, ended_at=now,
                )
                logger.info("Appel %s : aucun agent disponible.", session.pk)
                return {"session": session, "jitsi": None, "ring_seconds": 0,
                        "unavailable": True}
            session = CallSession.objects.create(
                caller=caller, business=business, room=room, billing_type=billing,
                state=SessionState.RINGING, ringing_at=now,
                expires_at=now + timedelta(seconds=settings.CALL_RING_SECONDS),
            )
            events.publish(events.RINGING, events.ringing_payload(
                session, settings.CALL_RING_SECONDS))
            join = _join_for_caller(session, caller)
    except IntegrityError:
        # Course perdue contre une autre requête du même appelant (contrainte en base).
        active = CallSession.objects.filter(
            caller=user, state__in=(SessionState.RINGING, SessionState.ANSWERED)
        ).values_list("pk", flat=True).first()
        raise _conflict(
            "call_already_active", "Vous avez déjà un appel en cours.",
            session_id=str(active) if active else None,
        ) from None
    logger.info("Appel %s : sonnerie lancée.", session.pk)
    return {"session": session, "jitsi": join, "ring_seconds": settings.CALL_RING_SECONDS,
            "unavailable": False}


def get_caller_session(user, session_id) -> CallSession:
    """Session de l'appelant (404 pour celle d'un autre, sans rien révéler)."""
    expire_stale(caller_id=user.pk, session_id=session_id)
    session = CallSession.objects.filter(pk=session_id, caller=user).first()
    if session is None:
        raise _not_found()
    return session


def cancel(user, session_id) -> CallSession:
    """L'appelant raccroche avant réponse."""
    session = get_caller_session(user, session_id)
    if session.state == SessionState.CANCELLED:
        return session
    if session.state != SessionState.RINGING:
        raise _conflict("call_not_ringing", "Cet appel n'est plus en sonnerie.")
    if not _finish(session.pk, SessionState.RINGING, SessionState.CANCELLED,
                   EndReason.CALLER_CANCEL, events.CANCELLED):
        session.refresh_from_db()
        if session.state != SessionState.CANCELLED:
            raise _conflict("call_not_ringing", "Cet appel n'est plus en sonnerie.")
    session.refresh_from_db()
    return session


def end_by_caller(user, session_id) -> CallSession:
    session = get_caller_session(user, session_id)
    return _end(session, EndReason.CALLER_HANGUP)


def end_by_agent(agent, session_id) -> CallSession:
    session = CallSession.objects.filter(pk=session_id, agent=agent).first()
    if session is None:
        raise _not_found()
    return _end(session, EndReason.AGENT_HANGUP)


def _end(session, reason: str) -> CallSession:
    if session.state == SessionState.ENDED:
        return session  # idempotent : l'autre côté a déjà raccroché
    if session.state != SessionState.ANSWERED:
        raise _conflict("call_not_answered", "Cet appel n'est pas en cours.")
    _finish(session.pk, SessionState.ANSWERED, SessionState.ENDED, reason, events.ENDED)
    session.refresh_from_db()
    return session


# --- Côté agent --------------------------------------------------------------------------


def accept(agent, session_id) -> dict:
    """Le premier agent qui répond gagne (mise à jour atomique ringing -> answered)."""
    jitsi.ensure_configured()
    now = timezone.now()
    with transaction.atomic():
        won = CallSession.objects.filter(
            pk=session_id, state=SessionState.RINGING, expires_at__gt=now
        ).update(state=SessionState.ANSWERED, agent=agent, answered_at=now)
        if not won:
            current = CallSession.objects.filter(pk=session_id).values_list(
                "state", flat=True).first()
            if current is None:
                raise _not_found()
            if current == SessionState.ANSWERED:
                raise _conflict("call_taken", "Un collègue a déjà répondu à cet appel.")
            raise _conflict("call_not_ringing", "Cet appel n'est plus en sonnerie.")
        session = CallSession.objects.select_related("caller", "business").get(pk=session_id)
        events.publish(events.TAKEN, {"session_id": str(session.pk), "state": session.state,
                                      "reason": "", "agent_id": agent.pk})
        join = jitsi.build_join(
            session.room, user_id=agent.pk, display_name=_display_name(agent), moderator=True
        )
    logger.info("Appel %s : répondu par l'agent %s.", session.pk, agent.pk)
    return {"session": session, "jitsi": join}


def decline(agent, session_id) -> CallSession:
    """L'agent refuse. Si plus aucun agent disponible n'a la main, l'appel passe à `declined`."""
    now = timezone.now()
    with transaction.atomic():
        session = CallSession.objects.select_for_update().filter(pk=session_id).first()
        if session is None:
            raise _not_found()
        if session.state != SessionState.RINGING or (
            session.expires_at and session.expires_at <= now
        ):
            raise _conflict("call_not_ringing", "Cet appel n'est plus en sonnerie.")
        CallSessionDecline.objects.get_or_create(session=session, agent=agent)
        declined_ids = set(session.declines.values_list("agent_id", flat=True))
        remaining = presence.available_agents(now).exclude(pk__in=declined_ids).exists()
    logger.info("Appel %s : refusé par l'agent %s.", session.pk, agent.pk)
    if not remaining:
        _finish(session.pk, SessionState.RINGING, SessionState.DECLINED,
                EndReason.ALL_DECLINED, events.DECLINED)
    session.refresh_from_db()
    return session


def ringing_sessions(now=None) -> list[dict]:
    """Sonneries en cours, rejouées à la connexion d'un agent."""
    now = now or timezone.now()
    rows = CallSession.objects.filter(
        state=SessionState.RINGING, expires_at__gt=now
    ).select_related("caller", "business").order_by("created_at")
    return [
        events.ringing_payload(s, max(0, int((s.expires_at - now).total_seconds())))
        for s in rows
    ]


def agent_tick(user_id: int) -> bool:
    """Battement de cœur d'un flux agent. Faux = le flux doit se fermer (droit retiré,
    compte bloqué…). Referme aussi les sonneries expirées."""
    from apps.admin_panel.services import rights_service

    user = User.objects.filter(pk=user_id).first()
    if user is None or not rights_service.has_admin_permission(
        user, rights_service.REPONDRE_APPELS
    ):
        return False
    presence.heartbeat(user_id)
    expire_stale()
    return True


def caller_tick(user_id: int, session_id) -> CallSession | None:
    """État à jour d'une session pour le flux de l'appelant (referme une sonnerie dépassée)."""
    expire_stale(caller_id=user_id, session_id=session_id)
    return CallSession.objects.filter(pk=session_id, caller_id=user_id).first()

