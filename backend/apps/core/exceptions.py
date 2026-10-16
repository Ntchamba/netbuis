"""Gestionnaire d'erreurs DRF : toujours `{code, message}` en français simple."""
from rest_framework import exceptions, status
from rest_framework.views import exception_handler

MESSAGES = {
    status.HTTP_400_BAD_REQUEST: "Certaines informations sont incorrectes.",
    status.HTTP_401_UNAUTHORIZED: "Veuillez vous connecter.",
    status.HTTP_403_FORBIDDEN: "Vous n'avez pas accès à cette action.",
    status.HTTP_404_NOT_FOUND: "Élément introuvable.",
    status.HTTP_405_METHOD_NOT_ALLOWED: "Action non disponible.",
    status.HTTP_429_TOO_MANY_REQUESTS: "Trop d'essais. Réessayez plus tard.",
}
DEFAULT_MESSAGE = "Une erreur est survenue. Réessayez."


class ApiError(exceptions.APIException):
    """Erreur métier : son message (en français) est renvoyé tel quel au client."""


def api_exception_handler(exc, context):
    response = exception_handler(exc, context)
    if response is None:
        return None
    if isinstance(exc, exceptions.APIException):
        code = exc.get_codes()
        code = code if isinstance(code, str) else "invalid"
    else:  # Http404 / PermissionDenied de Django, convertis par DRF
        code = {404: "not_found", 403: "permission_denied"}.get(response.status_code, "error")
    if isinstance(exc, ApiError):
        message = str(exc.detail)
    else:
        message = MESSAGES.get(response.status_code, DEFAULT_MESSAGE)
    body = {"code": code, "message": message}
    if isinstance(exc, exceptions.ValidationError):
        body["fields"] = response.data
    response.data = body
    return response
