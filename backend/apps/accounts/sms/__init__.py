"""Choix du fournisseur SMS selon le réglage SMS_PROVIDER (« console » ou « real »)."""
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured

from .base import SmsBackend
from .console_backend import ConsoleSmsBackend
from .real_provider import RealSmsProvider

PROVIDERS = {"console": ConsoleSmsBackend, "real": RealSmsProvider}


def get_sms_provider() -> SmsBackend:
    try:
        provider = PROVIDERS[settings.SMS_PROVIDER]
    except KeyError:
        raise ImproperlyConfigured(f"SMS_PROVIDER inconnu : {settings.SMS_PROVIDER!r}") from None
    return provider()
