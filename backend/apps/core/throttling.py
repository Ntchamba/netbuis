"""Limites de débit nommées (taux dans REST_FRAMEWORK['DEFAULT_THROTTLE_RATES'])."""
from rest_framework.throttling import AnonRateThrottle, UserRateThrottle


class OtpRateThrottle(AnonRateThrottle):
    """Demandes de code, par IP ; limite par numéro : apps.accounts.services.rate_limit."""

    scope = "otp"


class OtpVerifyRateThrottle(AnonRateThrottle):
    """Vérifications de code, par IP (compteur séparé de celui des demandes)."""

    scope = "otp_verify"


class CallRateThrottle(UserRateThrottle):
    """Par compte (anti-aspiration des numéros, D-05)."""

    scope = "call"
