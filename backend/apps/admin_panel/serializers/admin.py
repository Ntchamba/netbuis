"""Réglages et administrateurs (T074). Numéros toujours MASQUÉS ; le mot de passe temporaire
n'apparaît que dans la réponse de création (`AdminCreatedSerializer`)."""
from rest_framework import serializers

from apps.admin_panel.serializers.account import masked
from apps.admin_panel.services import account_service, admin_service


class SettingSerializer(serializers.Serializer):
    key = serializers.CharField()
    label = serializers.CharField()
    value = serializers.IntegerField()
    default = serializers.IntegerField()
    min = serializers.IntegerField()
    max = serializers.IntegerField()
    modified_by = serializers.IntegerField(allow_null=True)
    updated_at = serializers.DateTimeField(allow_null=True)


class SettingUpdateSerializer(serializers.Serializer):
    # Pas de IntegerField DRF : il accepterait « 5 » ou 5.0 ; le service exige un vrai entier.
    value = serializers.JSONField()
    reason = serializers.CharField(
        required=False, allow_blank=True, max_length=500,
        help_text="Commentaire facultatif, ajouté au journal d'audit.",
    )


class AdminSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    phone_masked = serializers.SerializerMethodField()
    roles = serializers.SerializerMethodField()
    status = serializers.SerializerMethodField(help_text="actif, bloque ou supprime")
    created_at = serializers.DateTimeField()

    def get_phone_masked(self, obj) -> str:
        return masked(obj)

    def get_roles(self, obj) -> list[str]:
        return admin_service.roles_of(obj)

    def get_status(self, obj) -> str:
        return account_service.account_status(obj)


class AdminCreateSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=32, help_text="Numéro camerounais (6XXXXXXXX…)")
    name = serializers.CharField(max_length=120, trim_whitespace=True)
    role = serializers.ChoiceField(choices=list(admin_service.ROLES))


class AdminCreatedSerializer(AdminSerializer):
    temporary_password = serializers.SerializerMethodField(
        help_text="Mot de passe temporaire : montré UNE SEULE FOIS, à transmettre à la "
                  "personne par un canal sûr. Jamais relisible ensuite."
    )

    def get_temporary_password(self, obj) -> str:
        return self.context["temporary_password"]


class AdminRoleSerializer(serializers.Serializer):
    role = serializers.ChoiceField(choices=list(admin_service.ROLES))


class AdminRemoveSerializer(serializers.Serializer):
    reason = serializers.CharField(
        required=False, allow_blank=True, trim_whitespace=True,
        help_text="Motif OBLIGATOIRE (1000 caractères au plus).",
    )
