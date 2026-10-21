"""Entrée et sortie de POST /api/calls/initiate/."""
from rest_framework import serializers

from apps.calls.models import Operator, Platform


class InitiateSerializer(serializers.Serializer):
    business_id = serializers.IntegerField(min_value=1)
    # T050 : appel seulement. Le canal WhatsApp est ajouté par T051.
    channel = serializers.ChoiceField(choices=["call"])
    platform = serializers.ChoiceField(choices=Platform.choices)
    operator = serializers.ChoiceField(choices=Operator.choices, required=False)


class InitiateResponseSerializer(serializers.Serializer):
    """Seul endroit de l'API qui renvoie le numéro d'un commerçant."""

    call_id = serializers.IntegerField()
    phone = serializers.CharField(help_text="Numéro du commerçant (+2376XXXXXXXX), pour cet appel.")


class ErrorCodeSerializer(serializers.Serializer):
    code = serializers.ChoiceField(choices=[
        "NOT_AUTHENTICATED", "ACCOUNT_BLOCKED", "BUSINESS_NOT_ACTIVE", "OWN_BUSINESS",
        "RATE_LIMITED", "CHANNEL_UNAVAILABLE",
    ])
    message = serializers.CharField()
