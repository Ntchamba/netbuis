"""Sérialiseur public du catalogue de produits (complétion). Aucun numéro de téléphone ici."""
from rest_framework import serializers

from apps.catalog.models import CatalogProduct


class CatalogProductSerializer(serializers.ModelSerializer):
    sector = serializers.SerializerMethodField(help_text="Code du secteur, ou null.")
    subcategory = serializers.SerializerMethodField(help_text="Code de la sous-catégorie, ou null.")

    class Meta:
        model = CatalogProduct
        fields = ("id", "name", "sector", "subcategory")
        read_only_fields = fields

    def get_sector(self, obj) -> str | None:
        return obj.category.sector.code if obj.category_id else None

    def get_subcategory(self, obj) -> str | None:
        return obj.category.code if obj.category_id else None
