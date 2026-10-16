"""Codes SMS (OTP) : demande et vérification. Zone sensible : relue ligne par ligne.

Règles (BACKLOG T006, T006b) : 6 chiffres, stocké haché (HMAC-SHA256), valable 5 min,
usage unique. Seul le dernier code demandé pour un numéro est valable.
Au 5e code faux en 1 heure pour un numéro (tous codes confondus), le numéro est bloqué
1 heure (ni demande ni vérification).
"""
import hashlib
import hmac
import secrets
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.utils import timezone
from rest_framework import exceptions, status

from apps.accounts.models import OtpCode, User
from apps.accounts.sms import get_sms_provider
from apps.core.exceptions import ApiError
from apps.core.utils.phone import normalize_phone

from .rate_limit import (
    PHONE_BLOCK,
    PHONE_MAX_WRONG,
    lock_phone,
    phone_blocked_for,
    phone_retry_after,
    phone_wrong_codes,
)

OTP_LIFETIME = timedelta(minutes=5)
OTP_MAX_ATTEMPTS = 5


class InvalidPhone(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "invalid_phone"
    default_detail = (
        "Numéro invalide. Entrez un numéro mobile camerounais à 9 chiffres commençant par 6."
    )


class OtpInvalid(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "otp_invalid"
    default_detail = "Code incorrect. Vérifiez le code reçu par SMS."


class OtpExpired(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "otp_expired"
    default_detail = "Ce code a expiré. Demandez un nouveau code."


class OtpTooManyAttempts(ApiError):
    status_code = status.HTTP_429_TOO_MANY_REQUESTS
    default_code = "too_many_requests"
    default_detail = "Trop d'essais pour ce code. Demandez un nouveau code."


class AccountBlocked(ApiError):
    status_code = status.HTTP_403_FORBIDDEN
    default_code = "account_blocked"
    default_detail = "Ce compte est bloqué. Contactez le support."


class AccountDeleted(ApiError):
    status_code = status.HTTP_403_FORBIDDEN
    default_code = "account_deleted"
    default_detail = "Ce compte a été supprimé. Contactez le support."


class TooManyRequests(exceptions.Throttled):
    """429 avec l'en-tête Retry-After (ajouté par DRF à partir de `wait`)."""

    default_code = "too_many_requests"


def parse_phone(raw: str) -> str:
    """Numéro saisi -> E.164 (+2376XXXXXXXX), ou erreur 400 invalid_phone."""
    try:
        return normalize_phone(raw)
    except ValueError:
        raise InvalidPhone() from None


def hash_code(phone: str, code: str) -> str:
    """HMAC-SHA256 du code avec la clé SECRET_KEY ; le numéro est inclus,
    donc un haché ne vaut que pour ce numéro."""
    message = f"{phone}:{code}".encode()
    return hmac.new(settings.SECRET_KEY.encode(), message, hashlib.sha256).hexdigest()


def request_code(phone: str) -> None:
    """Crée un code pour `phone` (déjà normalisé) et l'envoie par SMS."""
    code = f"{secrets.randbelow(1_000_000):06d}"
    # Si l'envoi échoue, le code n'est pas enregistré.
    with transaction.atomic():
        # Verrou sur le numéro : comptage et création dans la même transaction,
        # donc jamais plus de 3 demandes par 10 minutes, même simultanées.
        lock_phone(phone)
        wait = phone_blocked_for(phone) or phone_retry_after(phone)
        if wait:
            raise TooManyRequests(wait)
        OtpCode.objects.create(
            phone=phone,
            code_hash=hash_code(phone, code),
            expires_at=timezone.now() + OTP_LIFETIME,
        )
        get_sms_provider().send(phone, f"Votre code NetBuis : {code} (valable 5 min)")


def verify_code(phone: str, code: str) -> tuple[User, bool]:
    """Vérifie le code ; renvoie (compte, créé_maintenant). Lève une ApiError sinon."""
    with transaction.atomic():
        # Verrou : deux vérifications simultanées ne peuvent pas utiliser le même code.
        latest = OtpCode.objects.select_for_update().filter(phone=phone).order_by("-created_at")
        otp = latest.first()
        now = timezone.now()
        blocked = phone_blocked_for(phone)
        if blocked:
            error = TooManyRequests(blocked)
        elif otp is None or otp.used_at is not None:
            error = OtpInvalid()
        elif otp.expires_at <= now:
            error = OtpExpired()
        elif otp.attempts >= OTP_MAX_ATTEMPTS:
            error = OtpTooManyAttempts()
        elif not hmac.compare_digest(hash_code(phone, code), otp.code_hash):  # temps constant
            # Compté par numéro (pas seulement par code) : redemander un code ne remet
            # pas le compteur à zéro. +1 = l'essai en cours, pas encore enregistré.
            if phone_wrong_codes(phone) + 1 >= PHONE_MAX_WRONG:
                otp.blocked_until = now + PHONE_BLOCK
            otp.attempts += 1
            otp.save(update_fields=["attempts", "blocked_until"])
            error = OtpInvalid()
        else:
            otp.used_at = now
            otp.save(update_fields=["used_at"])
            error = None
    # Levée hors de la transaction pour que l'essai raté reste compté.
    if error is not None:
        raise error

    user = User.objects.filter(phone=phone).first()
    if user is None:
        return User.objects.create_user(phone), True
    if not user.can_login():
        raise AccountDeleted() if user.is_deleted else AccountBlocked()
    return user, False
