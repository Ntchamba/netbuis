"""Sérialiseurs publics (lecture seule) des référentiels. Aucun numéro de téléphone ici."""
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.catalog.models import Sector, ServiceCategory, StructureType, Subcategory


class SubcategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Subcategory
        fields = ("id", "code", "name", "icon", "order")
        read_only_fields = fields


class SectorSerializer(serializers.ModelSerializer):
    subcategories = serializers.SerializerMethodField(
        help_text="Sous-catégories actives du secteur, triées par ordre puis nom."
    )

    class Meta:
        model = Sector
        fields = ("id", "code", "name", "icon", "order", "subcategories")
        read_only_fields = fields

    @extend_schema_field(SubcategorySerializer(many=True))
    def get_subcategories(self, obj):
        # `active_subcategories` est posé par la vue (Prefetch) ; sinon on filtre ici.
        subs = getattr(obj, "active_subcategories", None)
        if subs is None:
            subs = obj.subcategories.filter(is_active=True)
        return SubcategorySerializer(subs, many=True).data


class ServiceCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = ServiceCategory
        fields = ("id", "code", "name", "icon", "order")
        read_only_fields = fields


class StructureTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = StructureType
        fields = ("id", "code", "name", "icon", "order")
        read_only_fields = fields
