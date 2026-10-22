"""Erreurs métier du forum : `{code, message}` au format commun."""
from rest_framework import status

from apps.core.exceptions import ApiError


class DailyPostLimit(ApiError):
    status_code = status.HTTP_429_TOO_MANY_REQUESTS
    default_code = "daily_post_limit"
    default_detail = "Vous avez atteint la limite de publications pour aujourd'hui."


class CommentRateLimit(ApiError):
    status_code = status.HTTP_429_TOO_MANY_REQUESTS
    default_code = "comment_rate_limit"
    default_detail = "Vous commentez trop vite. Réessayez dans quelques minutes."


class AlreadyReported(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "already_reported"
    default_detail = "Vous avez déjà signalé ce contenu."


class OwnContent(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "own_content"
    default_detail = "Vous ne pouvez pas signaler votre propre contenu."
