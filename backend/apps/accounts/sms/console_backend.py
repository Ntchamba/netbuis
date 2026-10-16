"""Fournisseur de développement : affiche le SMS sur la console du serveur (DEBUG=True)."""
import sys

from django.conf import settings
from django.core.exceptions import ImproperlyConfigured

from .base import SmsBackend


class ConsoleSmsBackend(SmsBackend):
    def __init__(self):
        if not settings.DEBUG:
            raise ImproperlyConfigured(
                "Le fournisseur SMS « console » ne fonctionne qu'avec DEBUG=True."
            )

    def send(self, phone: str, message: str) -> None:
        # Écrit sur la console, pas dans les logs : seuls les 2 derniers chiffres du numéro.
        sys.stdout.write(f"[SMS console] au numéro finissant par {phone[-2:]} : {message}\n")
        sys.stdout.flush()
