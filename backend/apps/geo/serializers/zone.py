"""Sérialiseurs des zones (lecture seule, publics). Aucun numéro de téléphone ici."""
from rest_framework import serializers

from apps.geo.models import Zone


class ZoneSerializer(serializers.ModelSerializer):
    class Meta:
        model = Zone
        fields = (
            "id", "name", "level", "parent", "official_code", "order", "latitude", "longitude"
        )
        read_only_fields = fields


class ZonePathItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = Zone
        fields = ("id", "name", "level")
        read_only_fields = fields


class ZoneDetailSerializer(ZoneSerializer):
    path = serializers.SerializerMethodField(
        help_text="Les parents du pays jusqu'à la zone incluse (id, nom, niveau)."
    )

    class Meta(ZoneSerializer.Meta):
        fields = ZoneSerializer.Meta.fields + ("path",)
        read_only_fields = fields

    def get_path(self, obj) -> list[dict]:
        return ZonePathItemSerializer(obj.get_path(), many=True).data
