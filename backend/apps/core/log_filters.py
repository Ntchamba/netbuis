"""Filtre de journalisation : aucun numéro de téléphone ni code OTP en clair dans les logs."""
import logging
import re

# +237 6XXXXXXXX, 2376XXXXXXXX, 6XXXXXXXX (espaces/points/tirets tolérés).
_PHONE = re.compile(r"(?:\+?237[\s.\-]?)?6(?:[\s.\-]?\d){8}")
# Code OTP : 6 chiffres isolés.
# ponytail: masque aussi tout autre nombre isolé de 6 chiffres (ex. un montant 150000).
_OTP = re.compile(r"(?<!\d)\d{6}(?!\d)")


def mask_personal_data(text: str) -> str:
    text = _PHONE.sub("[numéro masqué]", text)
    return _OTP.sub("[code masqué]", text)


class PersonalDataFilter(logging.Filter):
    def filter(self, record):
        record.msg = mask_personal_data(record.getMessage())
        record.args = None
        return True
