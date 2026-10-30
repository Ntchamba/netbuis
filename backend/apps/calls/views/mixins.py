"""Réponses qui touchent un appel : jamais mises en cache ; champs d'erreur supplémentaires."""
from rest_framework.negotiation import BaseContentNegotiation


class NoStoreMixin:
    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = "no-store"
        return response


class ExtraErrorFieldsMixin:
    """Ajoute à l'erreur `{code, message}` les champs de `CallRefused.extra` (par exemple
    `session_id` de l'appel déjà actif). Jamais de numéro, de salle ni de jeton."""

    def handle_exception(self, exc):
        response = super().handle_exception(exc)
        extra = getattr(exc, "extra", None)
        if extra and isinstance(response.data, dict):
            response.data.update({k: v for k, v in extra.items() if v is not None})
        return response


class EventStreamNegotiation(BaseContentNegotiation):
    """Un client SSE envoie `Accept: text/event-stream` : DRF le refuserait (406). Les erreurs
    restent en JSON, le flux est une réponse Django directe."""

    def select_parser(self, request, parsers):
        return parsers[0]

    def select_renderer(self, request, renderers, format_suffix=None):
        return renderers[0], renderers[0].media_type
