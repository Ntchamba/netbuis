"""Identité de l'administrateur connecté (T070). Numéro toujours masqué."""
from rest_framework import serializers

from apps.core.utils.phone import mask_phone


class AdminMeSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    phone_masked = serializers.CharField(help_text="Ex. « +237 6•• •• •• 12 »")
    roles = serializers.ListField(
        child=serializers.CharField(), help_text="Groupes : Validateur, Administrateur complet"
    )
    permissions = serializers.ListField(
        child=serializers.CharField(), help_text="Codes peut_… accordés par les groupes"
    )

    @staticmethod
    def build(user, roles, permissions) -> dict:
        return {
            "id": user.pk,
            "name": user.name,
            "phone_masked": mask_phone(user.phone),
            "roles": list(roles),
            "permissions": sorted(permissions),
        }
