"""Lecture du journal d'audit (T074c) : filtres admin, action, dates (de/à inclus)."""
import re
from datetime import date, datetime, time, timedelta

from django.utils import timezone
from rest_framework import status

from apps.core.exceptions import ApiError

from ..models import AuditAction, AuditLog


class InvalidAuditFilter(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "invalid_filter"
    default_detail = "Filtre invalide."


MIN_YEAR = 2000
_DIGITS = re.compile(r"[0-9]+")
_DATE = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}")


def _day(raw, name):
    """Date AAAA-MM-JJ stricte, de l'an 2000 à aujourd'hui + 1 an (sinon 400)."""
    message = f"`{name}` doit être une date AAAA-MM-JJ entre {MIN_YEAR} et dans un an au plus."
    if not _DATE.fullmatch(raw):
        raise InvalidAuditFilter(message)
    try:
        day = date.fromisoformat(raw)
    except ValueError as exc:
        raise InvalidAuditFilter(message) from exc
    today = timezone.localdate()
    if day.year < MIN_YEAR or day > today + timedelta(days=366):
        raise InvalidAuditFilter(message)
    return day


def _midnight(day):
    return timezone.make_aware(datetime.combine(day, time.min))


def list_queryset(*, admin=None, action=None, date_from=None, date_to=None):
    qs = AuditLog.objects.select_related("admin").order_by("-created_at", "-id")
    if admin not in (None, ""):
        if not _DIGITS.fullmatch(admin) or len(admin) > 18:
            raise InvalidAuditFilter("`admin` doit être un identifiant.")
        qs = qs.filter(admin_id=int(admin))
    if action not in (None, ""):
        if action not in AuditAction.values:
            raise InvalidAuditFilter("`action` inconnue.")
        qs = qs.filter(action=action)
    start = _day(date_from, "from") if date_from else None
    end = _day(date_to, "to") if date_to else None
    if start and end and start > end:
        raise InvalidAuditFilter("`from` doit précéder `to`.")
    if start:
        qs = qs.filter(created_at__gte=_midnight(start))
    if end:
        qs = qs.filter(created_at__lt=_midnight(end + timedelta(days=1)))
    return qs
