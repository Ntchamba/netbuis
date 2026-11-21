"""Appels vers l'équipe NetBuis, côté appelant (D-25)."""
from django.http import StreamingHttpResponse
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.calls.models import SignalRole
from apps.calls.serializers.sessions import (
    CallErrorSerializer,
    SessionCreateSerializer,
    SessionStartSerializer,
    SessionStateSerializer,
    SignalRequestSerializer,
    SignalResponseSerializer,
)
from apps.calls.services import session_service, signal_service, streams
from apps.calls.views.mixins import EventStreamNegotiation, ExtraErrorFieldsMixin, NoStoreMixin

_ERRORS = {
    401: OpenApiResponse(description="non connecté"),
    403: OpenApiResponse(description="account_blocked"),
}


class SessionCreateView(ExtraErrorFieldsMixin, NoStoreMixin, APIView):
    @extend_schema(
        operation_id="calls_sessions_create", tags=["calls"], request=SessionCreateSerializer,
        responses={
            200: SessionStartSerializer,
            404: OpenApiResponse(CallErrorSerializer, description="BUSINESS_NOT_ACTIVE"),
            409: OpenApiResponse(
                CallErrorSerializer,
                description="call_already_active (avec `session_id` de l'appel en cours)"),
            429: OpenApiResponse(CallErrorSerializer, description="RATE_LIMITED"),
            503: OpenApiResponse(CallErrorSerializer, description="jitsi_not_configured"),
            **_ERRORS,
        },
        description=(
            "Appelle l'équipe NetBuis. Crée la session, fait sonner les tableaux de bord des "
            "agents disponibles et renvoie de quoi établir l'audio dès maintenant : moteur "
            "`jitsi` (champ `jitsi`) ou `webrtc` (champ `webrtc.ice_servers` avec identifiants "
            "TURN temporaires, puis signalisation par `POST …/signal/`). Sans agent "
            "disponible : réponse immédiate `state=unavailable`, `code=no_agent_available`, "
            "accès `null`. Aucun numéro de commerçant n'est transmis."
        ),
    )
    def post(self, request):
        data = SessionCreateSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        result = session_service.create_session(
            request.user, data.validated_data.get("business_id")
        )
        session = result["session"]
        body = {
            "session_id": session.id, "state": session.state,
            "code": "no_agent_available" if result["unavailable"] else None,
            "engine": result["engine"], "jitsi": result["jitsi"], "webrtc": result["webrtc"],
            "ring_seconds": result["ring_seconds"],
        }
        return Response(SessionStartSerializer(body).data, status=status.HTTP_200_OK)


class SessionDetailView(NoStoreMixin, APIView):
    @extend_schema(
        operation_id="calls_sessions_read", tags=["calls"],
        responses={200: SessionStateSerializer, 404: OpenApiResponse(description="not_found"),
                   **_ERRORS},
        description=(
            "Consultation courte de l'état de ma session (repli si le flux temps réel "
            "est coupé). Ne renvoie ni la salle ni le jeton."
        ),
    )
    def get(self, request, pk):
        session = session_service.get_caller_session(request.user, pk)
        return Response(SessionStateSerializer(session).data)


class SessionEventsView(APIView):
    content_negotiation_class = EventStreamNegotiation

    @extend_schema(
        operation_id="calls_sessions_events", tags=["calls"],
        responses={(200, "text/event-stream"): OpenApiResponse(
            description=(
                "Flux SSE : événements `state` {session_id, state, reason} et, moteur `webrtc`, "
                "`signal` {session_id, signal_id, type, data} envoyés par l'agent (ceux déjà "
                "émis sont rejoués à l'ouverture ; ignorer un `signal_id` déjà vu) ; se termine "
                "à l'état final. Repli : GET /api/calls/sessions/{id}/."),
        ), 404: OpenApiResponse(description="not_found"), **_ERRORS},
        description="Flux temps réel de l'état de ma session (SSE sur ASGI, LISTEN/NOTIFY).",
    )
    def get(self, request, pk):
        session_service.get_caller_session(request.user, pk)  # 404 si ce n'est pas la mienne
        streams.release_request_connection()
        response = StreamingHttpResponse(
            streams.caller_stream(request.user.pk, pk), content_type="text/event-stream"
        )
        response["Cache-Control"] = "no-store"
        response["X-Accel-Buffering"] = "no"
        return response


class SessionEndView(NoStoreMixin, ExtraErrorFieldsMixin, APIView):
    @extend_schema(
        operation_id="calls_sessions_end", tags=["calls"], request=None,
        responses={200: SessionStateSerializer, 404: OpenApiResponse(description="not_found"),
                   409: OpenApiResponse(CallErrorSerializer, description="call_not_answered"),
                   **_ERRORS},
        description="Raccrocher un appel en cours (répété : sans effet).",
    )
    def post(self, request, pk):
        session = session_service.end_by_caller(request.user, pk)
        return Response(SessionStateSerializer(session).data)


class SessionCancelView(NoStoreMixin, ExtraErrorFieldsMixin, APIView):
    @extend_schema(
        operation_id="calls_sessions_cancel", tags=["calls"], request=None,
        responses={200: SessionStateSerializer, 404: OpenApiResponse(description="not_found"),
                   409: OpenApiResponse(CallErrorSerializer, description="call_not_ringing"),
                   **_ERRORS},
        description="Annuler avant que l'équipe réponde (répété : sans effet).",
    )
    def post(self, request, pk):
        return Response(SessionStateSerializer(session_service.cancel(request.user, pk)).data)


class SessionSignalView(NoStoreMixin, ExtraErrorFieldsMixin, APIView):
    @extend_schema(
        operation_id="calls_sessions_signal", tags=["calls"], request=SignalRequestSerializer,
        responses={
            201: SignalResponseSerializer,
            400: OpenApiResponse(description="type ou data invalide"),
            404: OpenApiResponse(description="not_found : pas ma session"),
            409: OpenApiResponse(
                CallErrorSerializer,
                description="call_not_active (ni en sonnerie ni en cours), "
                            "webrtc_not_enabled (moteur jitsi)"),
            413: OpenApiResponse(CallErrorSerializer, description="signal_too_large (> 16 Ko)"),
            429: OpenApiResponse(CallErrorSerializer,
                                 description="signal_quota_exceeded (200 par session)"),
            **_ERRORS,
        },
        description=(
            "Moteur `webrtc` : envoie un signal (`offer`, `candidate`, `bye`) à l'agent. Pendant "
            "la sonnerie il est conservé et rendu dans la réponse de `accept` ; ensuite il est "
            "relayé à l'agent par son flux SSE. Aucun contenu n'est journalisé."
        ),
    )
    def post(self, request, pk):
        data = SignalRequestSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        signal = signal_service.send(
            SignalRole.CALLER, request.user, pk, data.validated_data["type"],
            data.validated_data["data"])
        return Response(SignalResponseSerializer({"signal_id": signal.pk}).data,
                        status=status.HTTP_201_CREATED)
