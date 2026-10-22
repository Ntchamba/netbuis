"""Appels vers l'équipe NetBuis, côté tableau de bord (droit `peut_repondre_aux_appels`)."""
from django.http import StreamingHttpResponse
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from rest_framework.generics import ListAPIView
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.admin_panel.permissions import require
from apps.admin_panel.services.rights_service import REPONDRE_APPELS
from apps.calls.models import CallSession, SessionState
from apps.calls.serializers.sessions import (
    AcceptResponseSerializer,
    AgentCallSerializer,
    CallErrorSerializer,
    PresenceRequestSerializer,
    PresenceResponseSerializer,
    SessionStateSerializer,
)
from apps.calls.services import events, presence, session_service, streams
from apps.calls.views.mixins import EventStreamNegotiation, ExtraErrorFieldsMixin, NoStoreMixin

CanAnswerCalls = require(REPONDRE_APPELS)

_ERRORS = {
    401: OpenApiResponse(description="non connecté"),
    403: OpenApiResponse(description="droit « répondre aux appels » absent"),
}


class AgentStreamView(APIView):
    permission_classes = [CanAnswerCalls]
    content_negotiation_class = EventStreamNegotiation

    @extend_schema(
        operation_id="admin_calls_stream", tags=["admin-calls"],
        responses={(200, "text/event-stream"): OpenApiResponse(
            description=(
                "Flux SSE. Événements : `presence` {available}, `ringing` {session_id, state, "
                "caller_name, business, expires_at, ring_seconds_left}, `taken`, `ended`, "
                "`missed`, `declined`, `cancelled` {session_id, state, reason}, `closed`. "
                "À la connexion, les sonneries en cours sont rejouées. Un commentaire "
                "`: keepalive` toutes les 5 s."),
        ), **_ERRORS},
        description=(
            "Flux temps réel des appels pour un agent (SSE sur ASGI, PostgreSQL LISTEN/NOTIFY). "
            "Jeton administrateur dans l'en-tête Authorization ; le droit est relu à la "
            "connexion puis toutes les 5 s. Ni numéro, ni salle, ni jeton Jitsi."
        ),
    )
    def get(self, request):
        response = StreamingHttpResponse(
            streams.agent_stream(request.user.pk), content_type="text/event-stream"
        )
        response["Cache-Control"] = "no-store"
        response["X-Accel-Buffering"] = "no"
        return response


class PresenceView(NoStoreMixin, APIView):
    permission_classes = [CanAnswerCalls]

    @extend_schema(
        operation_id="admin_calls_presence", tags=["admin-calls"],
        request=PresenceRequestSerializer, responses={200: PresenceResponseSerializer, **_ERRORS},
        description=(
            "Choix Disponible / Indisponible (`available`) ou, sans corps, battement de cœur "
            "(toutes les 10 s environ). Un agent n'est appelé que s'il est Disponible, a un "
            "flux ouvert et une activité de moins de 25 s."
        ),
    )
    def post(self, request):
        data = PresenceRequestSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        pres = presence.set_available(request.user, data.validated_data.get("available"))
        return Response(PresenceResponseSerializer({"available": pres.available}).data)


class AcceptView(NoStoreMixin, ExtraErrorFieldsMixin, APIView):
    permission_classes = [CanAnswerCalls]

    @extend_schema(
        operation_id="admin_calls_accept", tags=["admin-calls"], request=None,
        responses={200: AcceptResponseSerializer, 404: OpenApiResponse(description="not_found"),
                   409: OpenApiResponse(CallErrorSerializer,
                                        description="call_taken, call_not_ringing"),
                   503: OpenApiResponse(CallErrorSerializer, description="jitsi_not_configured"),
                   **_ERRORS},
        description=(
            "Répondre. Le premier agent gagne (mise à jour atomique) ; les autres reçoivent "
            "409 et l'événement `taken`. Renvoie la salle et un jeton modérateur."
        ),
    )
    def post(self, request, pk):
        result = session_service.accept(request.user, pk)
        session = result["session"]
        business = session.business
        body = {
            "session_id": session.id, "caller_name": events.caller_display_name(session.caller),
            "business": {"id": business.pk, "name": business.name} if business else None,
            "jitsi": result["jitsi"],
        }
        return Response(AcceptResponseSerializer(body).data)


class DeclineView(NoStoreMixin, ExtraErrorFieldsMixin, APIView):
    permission_classes = [CanAnswerCalls]

    @extend_schema(
        operation_id="admin_calls_decline", tags=["admin-calls"], request=None,
        responses={200: SessionStateSerializer, 404: OpenApiResponse(description="not_found"),
                   409: OpenApiResponse(CallErrorSerializer, description="call_not_ringing"),
                   **_ERRORS},
        description=(
            "Refuser. Quand plus aucun agent disponible n'a la main, la session passe à "
            "`declined`."
        ),
    )
    def post(self, request, pk):
        return Response(SessionStateSerializer(session_service.decline(request.user, pk)).data)


class AgentEndView(NoStoreMixin, ExtraErrorFieldsMixin, APIView):
    permission_classes = [CanAnswerCalls]

    @extend_schema(
        operation_id="admin_calls_end", tags=["admin-calls"], request=None,
        responses={200: SessionStateSerializer, 404: OpenApiResponse(description="not_found"),
                   409: OpenApiResponse(CallErrorSerializer, description="call_not_answered"),
                   **_ERRORS},
        description="L'agent qui a répondu raccroche (répété : sans effet).",
    )
    def post(self, request, pk):
        session = session_service.end_by_agent(request.user, pk)
        return Response(SessionStateSerializer(session).data)


class AgentCallListView(NoStoreMixin, ListAPIView):
    permission_classes = [CanAnswerCalls]
    serializer_class = AgentCallSerializer

    def get_queryset(self):
        rows = CallSession.objects.select_related("caller", "business", "agent")
        states = [
            s for s in (self.request.query_params.get("state") or "").split(",")
            if s in SessionState.values
        ]
        if states:
            rows = rows.filter(state__in=states)
        agent = self.request.query_params.get("agent")
        if agent and agent.isdigit():
            rows = rows.filter(agent_id=int(agent))
        return rows.order_by("-created_at", "-id")

    @extend_schema(
        operation_id="admin_calls_list", tags=["admin-calls"],
        parameters=[
            OpenApiParameter("state", str, description=(
                "États séparés par des virgules (ringing, answered, ended, missed, declined, "
                "unavailable, cancelled). Appels manqués : `missed,declined`.")),
            OpenApiParameter("agent", int, description="Identifiant de l'agent qui a répondu."),
        ],
        responses={200: AgentCallSerializer(many=True), **_ERRORS},
        description=(
            "Appels vers l'équipe, du plus récent au plus ancien, 20 par page. Sans numéro de "
            "l'appelant et sans nom de salle."
        ),
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)
