"""Appels WebRTC directs (D-31, docs/spec/APPELS_WEBRTC.md) : choix du moteur et serveurs ICE.

Le serveur ne transporte pas l'audio : il donne aux deux pairs les adresses STUN/TURN et, pour
TURN, des identifiants TEMPORAIRES au format `use-auth-secret` de coturn :
    username   = "<expiration_unix>:<session_id>"
    credential = base64(HMAC-SHA1(TURN_SECRET, username))
Le secret n'est jamais renvoyé ni écrit dans un journal.
"""
import base64
import hashlib
import hmac
import logging
import time

from django.conf import settings

logger = logging.getLogger(__name__)

ENGINE_JITSI = "jitsi"
ENGINE_WEBRTC = "webrtc"
MIN_TURN_SECRET_LENGTH = 32


def engine() -> str:
    return settings.CALL_ENGINE


def is_webrtc() -> bool:
    return settings.CALL_ENGINE == ENGINE_WEBRTC


def turn_available() -> bool:
    return bool(settings.TURN_URLS) and (
        len(settings.TURN_SECRET.encode()) >= MIN_TURN_SECRET_LENGTH
    )


def turn_credentials(session_id, now: int | None = None) -> dict:
    """{username, credential} pour UNE session, valables `TURN_TTL` secondes."""
    expires = int(time.time() if now is None else now) + settings.TURN_TTL
    username = f"{expires}:{session_id}"
    digest = hmac.new(
        settings.TURN_SECRET.encode(), username.encode(), hashlib.sha1
    ).digest()
    return {"username": username, "credential": base64.b64encode(digest).decode()}


def ice_servers(session_id) -> list[dict]:
    """Liste `iceServers` pour `RTCPeerConnection`. Secret TURN absent ou trop court : STUN seul
    et une erreur est journalisée (sans valeur)."""
    servers: list[dict] = []
    if settings.STUN_URLS:
        servers.append({"urls": list(settings.STUN_URLS)})
    if settings.TURN_URLS:
        if turn_available():
            servers.append({"urls": list(settings.TURN_URLS),
                            **turn_credentials(session_id)})
        else:
            logger.error(
                "TURN non configuré : TURN_SECRET (%d caractères au moins) est obligatoire avec "
                "TURN_URLS ; STUN seul, aucun identifiant TURN émis.", MIN_TURN_SECRET_LENGTH,
            )
    return servers


def build_access(session_id) -> dict:
    return {"ice_servers": ice_servers(session_id)}
