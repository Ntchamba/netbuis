"""Comptes vus par l'administration (T072).

Liste : numéro MASQUÉ. Détail : `phone` en clair seulement pour l'Administrateur complet
(sinon null) ; `phone_masked` est toujours présent.
"""
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.admin_panel.serializers.business import BusinessRequestSerializer
from apps.admin_panel.services import account_service
from apps.core.utils.phone import mask_phone


def masked(user) -> str:
    try:
        return mask_phone(user.phone)
    except ValueError:
        return ""


class AccountListSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    phone_masked = serializers.SerializerMethodField(help_text="Ex. « +237 6•• •• •• 41 »")
    type = serializers.SerializerMethodField(help_text="simple ou business")
    status = serializers.SerializerMethodField(help_text="actif, bloque ou supprime")
    is_admin = serializers.BooleanField()
    is_blocked = serializers.BooleanField()
    is_deleted = serializers.BooleanField()
    business_name = serializers.SerializerMethodField()
    business_status = serializers.SerializerMethodField()
    zone_id = serializers.SerializerMethodField()
    zone_name = serializers.SerializerMethodField()
    created_at = serializers.DateTimeField()

    def _profile(self, obj):
        return obj.business_profile_or_none

    def get_phone_masked(self, obj) -> str:
        return masked(obj)

    def get_type(self, obj) -> str:
        return "business" if self._profile(obj) else "simple"

    def get_status(self, obj) -> str:
        return account_service.account_status(obj)

    @extend_schema_field(serializers.CharField(allow_null=True))
    def get_business_name(self, obj):
        profile = self._profile(obj)
        return profile.name if profile else None

    @extend_schema_field(serializers.CharField(allow_null=True))
    def get_business_status(self, obj):
        profile = self._profile(obj)
        return profile.status if profile else None

    @extend_schema_field(serializers.IntegerField(allow_null=True))
    def get_zone_id(self, obj):
        profile = self._profile(obj)
        return profile.zone_id if profile else None

    @extend_schema_field(serializers.CharField(allow_null=True))
    def get_zone_name(self, obj):
        profile = self._profile(obj)
        return profile.zone.name if profile else None


class AuditEntrySerializer(serializers.Serializer):
    action = serializers.CharField()
    label = serializers.SerializerMethodField()
    reason = serializers.CharField()
    admin_id = serializers.IntegerField()
    admin_name = serializers.CharField(source="admin.name")
    created_at = serializers.DateTimeField()

    def get_label(self, obj) -> str:
        return obj.get_action_display()

    class Meta:
        # Nom distinct de celui du journal d'audit (serializers/audit.py) : sinon les deux
        # schémas se confondent dans openapi.yaml.
        ref_name = "AccountAuditEntry"


class AccountDetailSerializer(AccountListSerializer):
    phone = serializers.SerializerMethodField(
        help_text="Numéro complet : Administrateur complet seulement (audité), sinon null"
    )
    language = serializers.CharField()
    blocked_reason = serializers.CharField()
    blocked_at = serializers.DateTimeField()
    deleted_at = serializers.DateTimeField()
    roles = serializers.SerializerMethodField(help_text="Groupes d'administration du compte")
    business = serializers.SerializerMethodField(
        help_text="Profil business et pièces (URL temporaires de 5 min), ou null"
    )
    status_history = serializers.SerializerMethodField()
    recent_audit = serializers.SerializerMethodField()

    @extend_schema_field(serializers.CharField(allow_null=True))
    def get_phone(self, obj):
        return self.context.get("full_phone")

    @extend_schema_field(serializers.ListField(child=serializers.CharField()))
    def get_roles(self, obj):
        from apps.admin_panel.services import rights_service

        return rights_service.admin_roles(obj)

    @extend_schema_field(BusinessRequestSerializer(allow_null=True))
    def get_business(self, obj):
        profile = self._profile(obj)
        if profile is None:
            return None
        return BusinessRequestSerializer(profile, context=self.context).data

    @extend_schema_field(AuditEntrySerializer(many=True))
    def get_status_history(self, obj):
        return AuditEntrySerializer(account_service.status_history(obj), many=True).data

    @extend_schema_field(AuditEntrySerializer(many=True))
    def get_recent_audit(self, obj):
        return AuditEntrySerializer(account_service.recent_audit(obj), many=True).data


class AccountStateSerializer(serializers.Serializer):
    """Réponse des actions : l'état du compte après l'action."""

    id = serializers.IntegerField()
    status = serializers.SerializerMethodField()
    is_blocked = serializers.BooleanField()
    is_deleted = serializers.BooleanField()
    blocked_reason = serializers.CharField()
    deleted_at = serializers.DateTimeField()

    def get_status(self, obj) -> str:
        return account_service.account_status(obj)


class AccountReasonSerializer(serializers.Serializer):
    reason = serializers.CharField(
        required=False, allow_blank=True, trim_whitespace=True,
        help_text="Motif (obligatoire pour bloquer : 255 caractères au plus ; "
                  "pour supprimer : 1000 au plus).",
    )
