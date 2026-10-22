"""Entrée et sortie de POST /api/calls/whatsapp/."""
from rest_framework import serializers

from apps.calls.models import Platform


class WhatsAppSerializer(serializers.Serializer):
    business_id = serializers.IntegerField(min_value=1)
    platform = serializers.ChoiceField(choices=Platform.choices)


class WhatsAppResponseSerializer(serializers.Serializer):
    call_id = serializers.IntegerField()
    wa_url = serializers.CharField(
        help_text="Lien https://wa.me/237… avec message pré-rempli (ouvre WhatsApp)."
    )
