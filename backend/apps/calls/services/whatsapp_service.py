"""Construit le lien wa.me (gratuit), côté serveur seulement."""
import re
from urllib.parse import quote

COUNTRY_CODE = "237"


def build_wa_url(phone: str, message: str) -> str:
    """`https://wa.me/237XXXXXXXXX?text=...` : chiffres seulement, indicatif 237, texte encodé."""
    digits = re.sub(r"\D", "", phone)
    if not digits.startswith(COUNTRY_CODE):
        digits = COUNTRY_CODE + digits
    return f"https://wa.me/{digits}?text={quote(message, safe='')}"


def prefilled_message(business_name: str) -> str:
    return f"Bonjour, je vous contacte depuis NetBuis au sujet de « {business_name} »."
