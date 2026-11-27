"""Entrées et sorties : retour d'appel, signalement WhatsApp, historique."""
from rest_framework import serializers

from apps.calls.models import FeedbackOutcome


class FeedbackSerializer(serializers.Serializer):
    outcome = serializers.ChoiceField(choices=FeedbackOutcome.choices)


class FeedbackResponseSerializer(serializers.Serializer):
    call_id = serializers.IntegerField()
    outcome = serializers.ChoiceField(choices=FeedbackOutcome.choices)


class WhatsAppReportSerializer(serializers.Serializer):
    business_id = serializers.IntegerField(min_value=1)


class WhatsAppReportResponseSerializer(serializers.Serializer):
    recorded = serializers.BooleanField()


class HistorySerializer(serializers.Serializer):
    """Aucun numéro ni lien : seulement ce que l'écran d'historique affiche.

    `type` = `call` (appel à l'équipe, ou ancien appel) ou `whatsapp`. `state` : état de la
    session d'appel (null pour un lien WhatsApp). `session_id` : identifiant de la session
    (null pour un lien WhatsApp ou un ancien appel). `id` : identifiant du journal WhatsApp ou
    de l'ancien appel (null pour une session) ; seul `id` accepte un retour d'appel.
    """

    id = serializers.IntegerField(allow_null=True)
    session_id = serializers.UUIDField(allow_null=True)
    type = serializers.CharField(help_text="`call` ou `whatsapp`.")
    state = serializers.CharField(allow_null=True)
    business_id = serializers.IntegerField(allow_null=True)
    business_name = serializers.CharField(allow_null=True)
    zone = serializers.CharField(allow_null=True)
    date = serializers.DateTimeField()
    feedback = serializers.CharField(allow_null=True)
