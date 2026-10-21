"""Masque les liens de lecture signés (pièces privées) dans les journaux (T071).

Django journalise le chemin de toute réponse 4xx (`django.request`) : le jeton contenu dans
`/api/admin/private-files/<jeton>/` ne doit jamais y figurer. Le filtre est posé au démarrage
(AdminPanelConfig.ready).
"""
import logging
import re

from django.conf import settings


def _pattern() -> re.Pattern:
    return re.compile(re.escape(settings.PRIVATE_DOWNLOAD_URL_PREFIX) + r"[^/\s?\"']+")


class SignedLinkFilter(logging.Filter):
    def filter(self, record):
        pattern = _pattern()
        replacement = settings.PRIVATE_DOWNLOAD_URL_PREFIX + "[lien masqué]"
        message = record.getMessage()
        if settings.PRIVATE_DOWNLOAD_URL_PREFIX in message:
            record.msg = pattern.sub(replacement, message)
            record.args = None
        # `extra["request"]` (WSGIRequest) porte aussi le chemin complet : on le retire.
        request = getattr(record, "request", None)
        if request is not None and settings.PRIVATE_DOWNLOAD_URL_PREFIX in str(
            getattr(request, "path", "")
        ):
            record.request = None
        return True
