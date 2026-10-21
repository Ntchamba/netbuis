"""Entrée et sortie de POST /api/calls/initiate/."""
from rest_framework import serializers

from apps.calls.models import Operator, Platform


class InitiateSerializer(serializers.Serializer):
    business_id = serializers.IntegerField(min_value=1)
    channel = serializers.ChoiceField(choices=["call", "whatsapp"])
    platform = serializers.ChoiceField(choices=Platform.choices)
    operator = serializers.ChoiceField(choices=Operator.choices, required=False)


class InitiateResponseSerializer(serializers.Serializer):
    """Seul endroit de l'API qui renvoie le numéro d'un commerçant."""

    call_id = serializers.IntegerField()
    phone = serializers.CharField(
        required=False,
        help_text="Canal call seulement : numéro du commerçant (+2376XXXXXXXX), pour cet appel.",
    )
    wa_url = serializers.CharField(
        required=False,
        help_text="Canal whatsapp seulement : lien https://wa.me/237… avec message pré-rempli.",
    )


class ErrorCodeSerializer(serializers.Serializer):
    code = serializers.ChoiceField(choices=[
        "NOT_AUTHENTICATED", "ACCOUNT_BLOCKED", "BUSINESS_NOT_ACTIVE", "OWN_BUSINESS",
        "RATE_LIMITED", "CHANNEL_UNAVAILABLE",
    ])
    message = serializers.CharField()
