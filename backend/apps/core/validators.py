"""Validateurs partagés."""
from django.core.exceptions import ValidationError

from apps.core.utils.phone import normalize_phone


def validate_cm_phone(value: str) -> None:
    try:
        normalize_phone(value)
    except ValueError as exc:
        raise ValidationError(str(exc), code="invalid_phone") from exc
