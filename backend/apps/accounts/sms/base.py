"""Interface commune des fournisseurs SMS (décision D-02)."""
from abc import ABC, abstractmethod


class SmsBackend(ABC):
    @abstractmethod
    def send(self, phone: str, message: str) -> None:
        """Envoie `message` au numéro E.164 `phone`. Lève une exception en cas d'échec."""
