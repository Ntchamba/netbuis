"""Analyses de recherche et d'appels (T074c, lecture seule, agrégats seulement).

- Fenêtre : `days` jours CALENDAIRES (fuseau du projet), aujourd'hui compris, de 1 à 90
  (7 par défaut).
- Recherches : le terme normalisé et un compteur. Jamais de compte (`account_hash` n'est pas lu).
  Un terme qui contient 6 chiffres ou plus (numéro tapé dans la barre de recherche) est écarté.
- Appels : chiffres par jour / opérateur / plateforme / canal. Ni appelant ni commerçant.
- Un nombre de requêtes constant, quel que soit le volume.
"""
import re
from datetime import datetime, time, timedelta

from django.db.models import Count, Q
from django.db.models.functions import TruncDate
from django.utils import timezone
from rest_framework import status

from apps.calls.models import CallChannel, CallLog, Operator, Platform
from apps.core.exceptions import ApiError
from apps.search.models import SearchLog

DEFAULT_DAYS = 7
MIN_DAYS, MAX_DAYS = 1, 90
TERMS_LIMIT = 50
UNKNOWN = "unknown"
_PHONE_LIKE = r"(\d[^\d]*){6,}"


class InvalidDays(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "invalid_days"
    default_detail = f"`days` doit être un entier de {MIN_DAYS} à {MAX_DAYS}."


def parse_days(raw) -> int:
    if raw in (None, ""):
        return DEFAULT_DAYS
    if not re.fullmatch(r"[0-9]{1,3}", str(raw)):
        raise InvalidDays()
    days = int(raw)
    if not MIN_DAYS <= days <= MAX_DAYS:
        raise InvalidDays()
    return days


def window(days: int, now=None):
    """(premier jour, début de ce jour à minuit local) pour `days` jours dont aujourd'hui."""
    now = timezone.localtime(now or timezone.now())
    first = now.date() - timedelta(days=days - 1)
    start = timezone.make_aware(datetime.combine(first, time.min))
    return first, start


def _top_terms(qs):
    rows = (
        qs.values("term").annotate(count=Count("pk")).order_by("-count", "term")[:TERMS_LIMIT]
    )
    return [{"term": r["term"], "count": r["count"]} for r in rows]


def searches(days: int, now=None) -> dict:
    first, start = window(days, now)
    qs = SearchLog.objects.filter(created_at__gte=start).exclude(term__regex=_PHONE_LIKE)
    totals = qs.aggregate(total=Count("pk"), none=Count("pk", filter=Q(results_count=0)))
    return {
        "days": days,
        "since": first,
        "total_searches": totals["total"],
        "total_without_results": totals["none"],
        "top_terms": _top_terms(qs),
        "no_result_terms": _top_terms(qs.filter(results_count=0)),
    }


def _breakdown(qs, field, keys, *, blank_as=None):
    counts = {k: 0 for k in keys}
    for row in qs.values(field).annotate(count=Count("pk")):
        key = row[field] or blank_as
        if key in counts:
            counts[key] += row["count"]
    return counts


def calls(days: int, now=None) -> dict:
    first, start = window(days, now)
    qs = CallLog.objects.filter(created_at__gte=start)
    per_day = {
        r["day"]: r["count"]
        for r in qs.annotate(day=TruncDate("created_at")).values("day").annotate(count=Count("pk"))
    }
    by_day = [
        {"date": first + timedelta(days=i), "count": per_day.get(first + timedelta(days=i), 0)}
        for i in range(days)
    ]
    return {
        "days": days,
        "since": first,
        "total_calls": sum(d["count"] for d in by_day),
        "by_day": by_day,
        "by_operator": _breakdown(
            qs, "operator", [Operator.ORANGE, Operator.MTN, UNKNOWN], blank_as=UNKNOWN),
        "by_platform": _breakdown(qs, "platform", [Platform.ANDROID, Platform.IOS]),
        "by_channel": _breakdown(qs, "channel", [CallChannel.CALL, CallChannel.WHATSAPP]),
    }
