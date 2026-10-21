"""Abonnements (T074c) : numéro toujours masqué."""
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.admin_panel.serializers.account import masked


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
