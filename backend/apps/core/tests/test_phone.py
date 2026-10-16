import pytest
from django.core.exceptions import ValidationError

from apps.core.utils.phone import normalize_phone
from apps.core.validators import validate_cm_phone


@pytest.mark.parametrize(
    "raw",
    ["699112233", "+237699112233", "237699112233", "00237699112233", "+237 6 99 11 22 33",
     "699-11-22-33"],
)
def test_normalize_phone_accepte_les_formats_courants(raw):
    assert normalize_phone(raw) == "+237699112233"


@pytest.mark.parametrize("raw", ["", "799112233", "69911223", "6991122334", "+33612345678", "abc"])
def test_normalize_phone_refuse_le_reste(raw):
    with pytest.raises(ValueError):
        normalize_phone(raw)


def test_validate_cm_phone():
    validate_cm_phone("699112233")
    with pytest.raises(ValidationError):
        validate_cm_phone("12345")
