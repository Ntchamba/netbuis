"""Réponse de GET /api/trends/ : produits et commerces, jamais de numéro ni de compte."""
from rest_framework import serializers


class TrendZoneSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()


class TrendProductSerializer(serializers.Serializer):
    id = serializers.IntegerField(help_text="Identifiant du produit du catalogue.")
    name = serializers.CharField(help_text="Nom à lancer comme recherche.")
    rank = serializers.IntegerField()


class TrendBusinessSerializer(serializers.Serializer):
    id = serializers.IntegerField(help_text="Identifiant du compte business (fiche publique).")
    name = serializers.CharField()
    zone = TrendZoneSerializer()
    rank = serializers.IntegerField()


class TrendsSerializer(serializers.Serializer):
    zone = TrendZoneSerializer(allow_null=True, help_text="Ville des tendances.")
    computed_at = serializers.DateTimeField(allow_null=True)
    period_days = serializers.IntegerField(allow_null=True)
    products = TrendProductSerializer(many=True, help_text="10 au plus.")
    businesses = TrendBusinessSerializer(many=True, help_text="10 au plus, actifs seulement.")
