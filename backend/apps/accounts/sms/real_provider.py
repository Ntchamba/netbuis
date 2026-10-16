"""Fournisseur SMS réel : pas encore choisi par Jeff (décision D-02).

La clé est lue dans la variable d'environnement SMS_API_KEY, jamais dans le code.
"""
import os

from django.core.exceptions import ImproperlyConfigured

from .base import SmsBackend


class RealSmsProvider(SmsBackend):
    def __init__(self):
        self.api_key = os.environ.get("SMS_API_KEY", "")
        if not self.api_key:
            raise ImproperlyConfigured(
                "SMS_API_KEY manquante : renseignez-la dans backend/.env pour SMS_PROVIDER=real."
            )

    def send(self, phone: str, message: str) -> None:
        raise ImproperlyConfigured("Fournisseur SMS réel pas encore choisi (décision D-02).")
