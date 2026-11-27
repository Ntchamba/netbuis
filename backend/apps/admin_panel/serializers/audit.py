"""Journal d'audit en lecture (T074c).

Le motif est écrit par un administrateur : à l'affichage, tout numéro de téléphone, code,
jeton ou lien (lien signé de pièce privée compris) est masqué, même si l'un d'eux y a été saisi.
"""
import re

from rest_framework import serializers

from apps.core.log_filters import mask_personal_data

_LINK = re.compile(r"(?:https?://|/api/)\S+")


def clean_reason(text: str) -> str:
    return mask_personal_data(_LINK.sub("[lien masqué]", text or ""))


class AuditEntrySerializer(serializers.Serializer):
    id = serializers.IntegerField()
    admin_id = serializers.IntegerField()
    admin_name = serializers.CharField(source="admin.name")
    action = serializers.CharField()
    action_label = serializers.CharField(source="get_action_display")
    target_type = serializers.CharField()
    target_id = serializers.IntegerField()
    reason = serializers.SerializerMethodField()
    created_at = serializers.DateTimeField()

    def get_reason(self, obj) -> str:
        return clean_reason(obj.reason)
