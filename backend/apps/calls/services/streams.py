"""Flux temps réel (SSE) alimentés par PostgreSQL `LISTEN/NOTIFY` (D-25, D-26).

Chaque flux ouvre SA connexion PostgreSQL directe et y fait `LISTEN` (aucun pool en mode
transaction : voir docs/deployment/). Le nombre de connexions ouvertes = agents connectés +
appels en cours : très faible ici.

Ordre voulu à l'ouverture : LISTEN d'abord, rejeu ensuite, pour ne perdre aucun événement.
Le nom de salle et les jetons ne passent jamais par ces flux.
"""
import json
from collections.abc import AsyncIterator
from contextlib import aclosing

import psycopg
from asgiref.sync import sync_to_async
from django.conf import settings
from django.db import connections
from psycopg.conninfo import make_conninfo

from apps.calls.services import events, presence, session_service

TICK_SECONDS = 5  # battement de cœur, présence, fermeture des sonneries expirées
RETRY_MS = 2000  # délai de reconnexion conseillé au navigateur

_TERMINAL = {s.value for s in session_service.TERMINAL_STATES}


def sse(event: str, data: dict) -> str:
    body = json.dumps(data, separators=(",", ":"), ensure_ascii=False)
    return f"event: {event}\ndata: {body}\n\n"


def sse_comment(text: str = "keepalive") -> str:
    return f": {text}\n\n"


def listen_conninfo() -> str:
    """Connexion DIRECTE à PostgreSQL pour `LISTEN` : `CALLS_LISTEN_DATABASE_URL` si elle est
    donnée (base derrière un pool en mode transaction), sinon la base par défaut."""
    cfg = connections["default"].settings_dict
    if settings.CALLS_LISTEN_DATABASE_URL:
        import environ

        cfg = environ.Env.db_url_config(settings.CALLS_LISTEN_DATABASE_URL)
    params = {
        "dbname": cfg.get("NAME"), "user": cfg.get("USER"), "password": cfg.get("PASSWORD"),
        "host": cfg.get("HOST"), "port": cfg.get("PORT"),
    }
    for key, value in (cfg.get("OPTIONS") or {}).items():
        if isinstance(value, str | int):
            params[key] = value
    return make_conninfo(**{k: v for k, v in params.items() if v not in (None, "")})


async def _listen() -> psycopg.AsyncConnection:
    conn = await psycopg.AsyncConnection.connect(listen_conninfo(), autocommit=True)
    await conn.execute(f"LISTEN {events.CHANNEL}")
    return conn


async def agent_stream(user_id: int) -> AsyncIterator[str]:
    """Flux d'un agent : présence, sonneries en cours, puis tous les événements d'appel."""
    conn = await _listen()
    opened = False
    try:
        user = await sync_to_async(_load_user)(user_id)
        pres = await sync_to_async(presence.open_stream)(user)
        opened = True
        yield f"retry: {RETRY_MS}\n\n"
        yield sse("presence", {"available": pres.available})
        ringing_seen: set[str] = set()
        for payload in await sync_to_async(session_service.ringing_sessions)():
            ringing_seen.add(payload["session_id"])
            yield sse(events.RINGING, payload)
        while True:
            async with aclosing(conn.notifies(timeout=TICK_SECONDS)) as notifies:
                async for notification in notifies:
                    data = json.loads(notification.payload)
                    name = data.pop("event")
                    if name == events.RINGING:
                        if data["session_id"] in ringing_seen:
                            continue
                        ringing_seen.add(data["session_id"])
                    yield sse(name, data)
            if not await sync_to_async(session_service.agent_tick)(user_id):
                yield sse("closed", {"reason": "permission_removed"})
                return
            yield sse_comment()
    finally:
        if opened:
            await sync_to_async(presence.close_stream)(user_id)
        await conn.close()


def _load_user(user_id: int):
    from apps.accounts.models import User

    return User.objects.get(pk=user_id)


def _caller_event(session) -> dict:
    return {"session_id": str(session.id), "state": session.state, "reason": session.end_reason}


async def caller_stream(user_id: int, session_id) -> AsyncIterator[str]:
    """Flux de l'appelant : l'état de SA session, jusqu'à la fin de l'appel."""
    conn = await _listen()
    wanted = str(session_id)
    try:
        yield f"retry: {RETRY_MS}\n\n"
        session = await sync_to_async(session_service.caller_tick)(user_id, session_id)
        if session is None:
            return
        yield sse("state", _caller_event(session))
        if session.state in _TERMINAL:
            return
        while True:
            async with aclosing(conn.notifies(timeout=TICK_SECONDS)) as notifies:
                async for notification in notifies:
                    data = json.loads(notification.payload)
                    if data.get("session_id") != wanted:
                        continue
                    state = data.get("state")
                    yield sse("state", {"session_id": wanted, "state": state,
                                        "reason": data.get("reason", "")})
                    if state in _TERMINAL:
                        return
            session = await sync_to_async(session_service.caller_tick)(user_id, session_id)
            if session is None:
                return
            if session.state in _TERMINAL:
                yield sse("state", _caller_event(session))
                return
            yield sse_comment()
    finally:
        await conn.close()


__all__ = ["agent_stream", "caller_stream"]
