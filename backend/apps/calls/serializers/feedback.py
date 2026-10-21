"""Entrées et sorties : retour d'appel, signalement WhatsApp, historique."""
from rest_framework import serializers

from apps.calls.models import CallLog, FeedbackOutcome


class FeedbackSerializer(serializers.Serializer):
    outcome = serializers.ChoiceField(choices=FeedbackOutcome.choices)


class FeedbackResponseSerializer(serializers.Serializer):
    call_id = serializers.IntegerField()
    outcome = serializers.ChoiceField(choices=FeedbackOutcome.choices)


class WhatsAppReportSerializer(serializers.Serializer):
    business_id = serializers.IntegerField(min_value=1)


class WhatsAppReportResponseSerializer(serializers.Serializer):
    recorded = serializers.BooleanField()


class HistorySerializer(serializers.ModelSerializer):
    """Aucun numéro ni lien : seulement ce que l'écran d'historique affiche."""

    business_id = serializers.IntegerField(source="profile_id")
    business_name = serializers.CharField(source="profile.name")
    zone = serializers.CharField(source="profile.zone.name")
    date = serializers.DateTimeField(source="created_at")
    type = serializers.CharField(source="channel")
    feedback = serializers.SerializerMethodField()

    class Meta:
        model = CallLog
        fields = ("id", "business_id", "business_name", "zone", "date", "type", "feedback")

    def get_feedback(self, obj) -> str | None:
        fb = getattr(obj, "feedback", None)
        return fb.outcome if fb else None
