"""Abonnements (T074c) : numéro toujours masqué."""
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.admin_panel.serializers.account import masked
from apps.admin_panel.services import audit_service, subscription_service


class SubscriptionRowSerializer(serializers.Serializer):
    id = serializers.IntegerField(help_text="Identifiant du compte business")
    name = serializers.CharField()
    owner_id = serializers.IntegerField()
    phone_masked = serializers.SerializerMethodField(help_text="Ex. « +237 6•• •• •• 41 »")
    zone_id = serializers.IntegerField(allow_null=True)
    zone_name = serializers.SerializerMethodField()
    is_subscribed = serializers.BooleanField()
    subscription_end = serializers.DateTimeField(
        allow_null=True, help_text="Fin de l'abonnement en cours, null si non abonné")
    calls_last_day = serializers.IntegerField(help_text="Appels reçus sur les dernières 24 h")
    calls_count = serializers.IntegerField(help_text="Appels lancés depuis l'ouverture")
    high_traffic = serializers.SerializerMethodField(
        help_text="Non abonné et au-dessus du seuil sur 24 h")

    def get_phone_masked(self, obj) -> str:
        return masked(obj.owner)

    @extend_schema_field(serializers.CharField(allow_null=True))
    def get_zone_name(self, obj):
        return obj.zone.name if obj.zone_id else None

    def get_high_traffic(self, obj) -> bool:
        return (not obj.is_subscribed) and obj.calls_last_day > self.context["threshold"]


class SubscriptionGrantSerializer(serializers.Serializer):
    business_id = serializers.IntegerField(
        min_value=1, help_text="Identifiant du compte business (profil) à abonner")
    duration_days = serializers.IntegerField(
        min_value=subscription_service.MIN_DAYS, max_value=subscription_service.MAX_DAYS,
        help_text="Durée en jours entiers, de 1 à 366, à partir de maintenant")
    reason = serializers.CharField(
        trim_whitespace=True, max_length=audit_service.MAX_REASON,
        help_text="Motif obligatoire (1000 caractères au plus), écrit dans le journal d'audit")


class SubscriptionGrantedSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    business_id = serializers.IntegerField(source="profile_id")
    business_name = serializers.CharField(source="profile.name")
    start = serializers.DateTimeField()
    end = serializers.DateTimeField()
    status = serializers.CharField()
    source = serializers.CharField()
    granted_by_id = serializers.IntegerField()
    granted_by_name = serializers.CharField(source="granted_by.name")
