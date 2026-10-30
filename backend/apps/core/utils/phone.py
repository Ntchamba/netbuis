"""Normalisation E.164 des numéros camerounais (+237…)."""
import re

# Mobile camerounais : 9 chiffres commençant par 6.
_CM_LOCAL = re.compile(r"^6\d{8}$")


def normalize_phone(raw: str) -> str:
    """`6XXXXXXXX`, `237 6XX…`, `+237-6XX…` -> `+2376XXXXXXXX`. Lève ValueError sinon."""
    digits = re.sub(r"[\s.\-()]", "", raw or "")
    if digits.startswith("+237"):
        digits = digits[4:]
    elif digits.startswith("00237"):
        digits = digits[5:]
    elif digits.startswith("237") and len(digits) == 12:
        digits = digits[3:]
    if not _CM_LOCAL.match(digits):
        raise ValueError("Numéro de téléphone camerounais invalide.")
    return "+237" + digits


def mask_phone(e164: str) -> str:
    """`+2376XXXXXXXX` -> `+237 6•• •• •• 12` (maquette Profil) : seuls le premier et
    les deux derniers chiffres restent visibles. Lève ValueError si le numéro est invalide."""
    digits = normalize_phone(e164)[4:]
    return f"+237 {digits[0]}•• •• •• {digits[-2:]}"
