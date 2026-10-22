"""Accès Jitsi (D-25) : nom de salle secret et jeton signé HS256.

Le serveur de l'application ne transporte JAMAIS l'audio : il distribue seulement le droit
d'entrer dans UNE salle. Domaine, identifiant d'application et secret viennent de
l'environnement. Ni le secret, ni le jeton, ni le nom de salle ne sont écrits dans un journal.
"""
import logging
import secrets
import time

import jwt
from django.conf import settings
from rest_framework import status

from apps.core.exceptions import ApiError

logger = logging.getLogger(__name__)

ROOM_BYTES = 24  # 192 bits d'aléa (au moins 128 exigés)
MIN_SECRET_LENGTH = 32  # octets : minimum de PyJWT pour HS256


class JitsiNotConfigured(ApiError):
    status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    default_code = "jitsi_not_configured"
    default_detail = "Les appels ne sont pas disponibles pour le moment."


def is_configured() -> bool:
    secret = settings.JITSI_JWT_SECRET
    return bool(
        settings.JITSI_DOMAIN and settings.JITSI_APP_ID
        and len(secret.encode()) >= MIN_SECRET_LENGTH
    )


def ensure_configured() -> None:
    """Lève 503 jitsi_not_configured et signale la configuration (sans valeur) dans le journal."""
    if not is_configured():
        logger.error(
            "Jitsi non configuré : JITSI_DOMAIN, JITSI_APP_ID et JITSI_JWT_SECRET "
            "(%d caractères au moins) sont obligatoires ; aucun jeton émis.", MIN_SECRET_LENGTH,
        )
        raise JitsiNotConfigured()


def new_room_name() -> str:
    return secrets.token_urlsafe(ROOM_BYTES)


def build_join(room: str, *, user_id: int, display_name: str, moderator: bool) -> dict:
    """{domain, room, jwt} pour entrer dans `room` (et seulement celle-là)."""
    ensure_configured()
    now = int(time.time())
    claims = {
        "iss": settings.JITSI_APP_ID,
        "aud": "jitsi",
        "sub": settings.JITSI_DOMAIN,
        "room": room,
        "iat": now,
        "nbf": now - 5,
        "exp": now + settings.JITSI_TOKEN_TTL,
        "context": {
            "user": {"id": str(user_id), "name": display_name, "moderator": moderator},
            "features": {
                "recording": False,
                "livestreaming": False,
                "transcription": False,
                "outbound-call": False,
            },
        },
    }
    token = jwt.encode(claims, settings.JITSI_JWT_SECRET, algorithm="HS256")
    return {"domain": settings.JITSI_DOMAIN, "room": room, "jwt": token}
