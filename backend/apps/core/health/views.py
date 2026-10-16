from django.db import connection
from django.http import JsonResponse


def health(request):
    """GET /api/health/ : 200 si la base répond, 503 sinon."""
    try:
        connection.ensure_connection()
        db = "ok"
    except Exception:  # noqa: BLE001
        db = "error"
    status = 200 if db == "ok" else 503
    return JsonResponse({"status": "ok" if db == "ok" else "degraded", "db": db}, status=status)
