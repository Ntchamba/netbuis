"""Entrées et sorties des appels vers l'équipe. Aucun numéro de téléphone nulle part."""
from rest_framework import serializers

from apps.calls.models import CallSession, SessionState


class SessionCreateSerializer(serializers.Serializer):
    business_id = serializers.IntegerField(
        min_value=1, required=False, allow_null=True,
        help_text="Commerce consulté (contexte seulement : le commerçant n'est jamais joint).",
    )


class JitsiAccessSerializer(serializers.Serializer):
    domain = serializers.CharField()
    room = serializers.CharField(help_text="Nom de salle secret : à ne jamais journaliser.")
    jwt = serializers.CharField(help_text="Jeton court limité à cette salle : ne pas journaliser.")


class SessionStartSerializer(serializers.Serializer):
    session_id = serializers.UUIDField()
    state = serializers.ChoiceField(
        choices=SessionState.choices, help_text="`ringing` ou `unavailable`.")
    code = serializers.CharField(
        allow_null=True, help_text="`no_agent_available` si personne n'est disponible."
    )
    jitsi = JitsiAccessSerializer(allow_null=True)
    ring_seconds = serializers.IntegerField()


class SessionStateSerializer(serializers.ModelSerializer):
    session_id = serializers.UUIDField(source="id")

    class Meta:
        model = CallSession
        fields = ("session_id", "state", "end_reason", "created_at", "expires_at",
                  "answered_at", "ended_at")


class BusinessContextSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    type_label = serializers.CharField(help_text="Type de compte en clair (« Entreprise »…).")
    kind = serializers.ChoiceField(choices=["entreprise", "particulier"])


class AcceptResponseSerializer(serializers.Serializer):
    session_id = serializers.UUIDField()
    caller_name = serializers.CharField()
    business = BusinessContextSerializer(allow_null=True)
    jitsi = JitsiAccessSerializer()


class PresenceRequestSerializer(serializers.Serializer):
    available = serializers.BooleanField(
        required=False, help_text="Absent = simple battement de cœur (toutes les 10 s environ)."
    )


class PresenceResponseSerializer(serializers.Serializer):
    available = serializers.BooleanField()


class AgentRefSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()


class AgentCallSerializer(serializers.ModelSerializer):
    """Ligne de la liste « Appels » du tableau de bord : pas de numéro, pas de salle."""

    session_id = serializers.UUIDField(source="id")
    caller_name = serializers.SerializerMethodField()
    business = serializers.SerializerMethodField()
    agent = serializers.SerializerMethodField()
    duration_seconds = serializers.SerializerMethodField()

    class Meta:
        model = CallSession
        fields = ("session_id", "state", "end_reason", "caller_name", "business", "agent",
                  "created_at", "answered_at", "ended_at", "duration_seconds")

    def get_caller_name(self, obj) -> str:
        from apps.calls.services.events import caller_display_name

        return caller_display_name(obj.caller)

    def get_business(self, obj) -> dict | None:
        return {"id": obj.business_id, "name": obj.business.name} if obj.business_id else None

    def get_agent(self, obj) -> dict | None:
        if not obj.agent_id:
            return None
        return {"id": obj.agent_id, "name": (obj.agent.name or "").strip() or "Agent"}

    def get_duration_seconds(self, obj) -> int | None:
        if obj.answered_at and obj.ended_at:
            return max(0, int((obj.ended_at - obj.answered_at).total_seconds()))
        return None


class CallErrorSerializer(serializers.Serializer):
    code = serializers.CharField()
    message = serializers.CharField()
    session_id = serializers.UUIDField(required=False)


class ContextCallerSerializer(serializers.Serializer):
    name = serializers.CharField()
    phone = serializers.CharField(
        help_text="Numéro de l'appelant (E.164). Agent qui a répondu seulement (D-30).")


class ContextHistorySerializer(serializers.Serializer):
    action = serializers.CharField()
    label = serializers.CharField()
    reason = serializers.CharField()
    admin_name = serializers.CharField()
    created_at = serializers.DateTimeField()


class ContextSubscriptionSerializer(serializers.Serializer):
    active = serializers.BooleanField()
    end = serializers.DateTimeField(allow_null=True)


class ContextBusinessSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    type_compte = serializers.CharField()
    type_label = serializers.CharField()
    kind = serializers.ChoiceField(choices=["entreprise", "particulier"])
    phone = serializers.CharField(
        help_text="Numéro du commerce visé (E.164). Agent qui a répondu seulement (D-30).")
    owner_name = serializers.CharField()
    category = serializers.CharField(allow_null=True)
    sous_categories = serializers.ListField(child=serializers.CharField())
    zone_name = serializers.CharField()
    zone_parent_name = serializers.CharField(allow_null=True)
    repere = serializers.CharField()
    description = serializers.CharField()
    representant_nom = serializers.CharField()
    forme_juridique = serializers.CharField()
    rccm = serializers.CharField()
    photo_url = serializers.CharField(allow_null=True)
    representant_photo_url = serializers.CharField(allow_null=True)
    status = serializers.CharField()
    cni_verifiee = serializers.BooleanField()
    motif_rejet = serializers.CharField()
    subscription = ContextSubscriptionSerializer()
    reports_count = serializers.IntegerField()
    whatsapp_reports_count = serializers.IntegerField()
    calls_count = serializers.IntegerField()
    views_count = serializers.IntegerField()
    created_at = serializers.DateTimeField()
    history = ContextHistorySerializer(many=True)


class CallContextSerializer(serializers.Serializer):
    session_id = serializers.UUIDField()
    state = serializers.CharField(help_text="Toujours `answered`.")
    caller = ContextCallerSerializer()
    business = ContextBusinessSerializer(allow_null=True)
