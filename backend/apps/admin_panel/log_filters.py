"""Masque les liens signés (jeton dans le chemin) dans les journaux (T071, étendu T089).

Django journalise le chemin de toute réponse 4xx (`django.request`) et de chaque requête du
serveur de développement (`django.server`). Les jetons de
`/api/admin/private-files/<jeton>/` (pièces privées) et `/api/uploads/local/<jeton>/`
(envoi en stockage local) ne doivent jamais y figurer. Le filtre est posé au démarrage
(AdminPanelConfig.ready) sur ces deux journaux ; il couvre le message ET les attributs
de l'enregistrement.
"""
import logging
import re

from django.conf import settings

MASK = "[lien masqué]"
UPLOAD_LOCAL_PREFIX = "/api/uploads/local/"


def signed_prefixes() -> tuple[str, ...]:
    return (settings.PRIVATE_DOWNLOAD_URL_PREFIX, UPLOAD_LOCAL_PREFIX)


def mask_signed_links(text: str) -> str:
    for prefix in signed_prefixes():
        if prefix in text:
            text = re.sub(re.escape(prefix) + r"[^/\s?\"']+", prefix + MASK, text)
    return text


def _has_link(text: str) -> bool:
    return any(prefix in text for prefix in signed_prefixes())


class SignedLinkFilter(logging.Filter):
    def filter(self, record):
        message = record.getMessage()
        if _has_link(message):
            record.msg = mask_signed_links(message)
            record.args = None
        for key, value in list(record.__dict__.items()):
            if key in ("msg", "args"):
                continue
            if isinstance(value, str) and _has_link(value):
                setattr(record, key, mask_signed_links(value))
            elif key == "request" and _has_link(str(getattr(value, "path", ""))):
                # `extra["request"]` (WSGIRequest) porte le chemin complet : on le retire.
                record.request = None
        return True
