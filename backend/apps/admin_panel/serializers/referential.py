"""Référentiels (T074b) : entrées validées et sorties. Aucune donnée personnelle."""
from rest_framework import serializers

from apps.catalog.models import CatalogProduct, Sector, Subcategory
from apps.catalog.models.category import code_validator
from apps.geo.models import Zone, ZoneLevel


class ReasonSerializer(serializers.Serializer):
    reason = serializers.CharField(
        required=False, allow_blank=True, max_length=500,
        help_text="Commentaire facultatif, ajouté au journal d'audit.",
    )


# --- Entrées -----------------------------------------------------------------------


class ZoneUpdateSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=150)
    parent = serializers.PrimaryKeyRelatedField(
        queryset=Zone.objects.all(), allow_null=True,
        help_text="Zone parente (niveau supérieur attendu) ; absente pour un pays.")
    official_code = serializers.CharField(max_length=30, allow_blank=True)
    order = serializers.IntegerField(min_value=0)
    latitude = serializers.FloatField(min_value=-90, max_value=90, allow_null=True)
    longitude = serializers.FloatField(min_value=-180, max_value=180, allow_null=True)


class ZoneCreateSerializer(ZoneUpdateSerializer):
    level = serializers.ChoiceField(choices=ZoneLevel.choices)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        for name in ("parent", "official_code", "order", "latitude", "longitude"):
            self.fields[name].required = False


class ItemUpdateSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=100)
    icon = serializers.CharField(max_length=16, allow_blank=True)
    order = serializers.IntegerField(min_value=0)


class ItemCreateSerializer(ItemUpdateSerializer):
    code = serializers.CharField(
        max_length=50, validators=[code_validator],
        help_text="Code stable (minuscules, chiffres, « _ ») ; non modifiable ensuite.")

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        for name in ("icon", "order"):
            self.fields[name].required = False


class SubcategoryCreateSerializer(ItemCreateSerializer):
    sector = serializers.PrimaryKeyRelatedField(queryset=Sector.objects.all())
    code = serializers.CharField(max_length=60, validators=[code_validator])


class ProductUpdateSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=150)
    category = serializers.PrimaryKeyRelatedField(
        queryset=Subcategory.objects.all(), allow_null=True)


class ProductCreateSerializer(ProductUpdateSerializer):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["category"].required = False


class SynonymUpdateSerializer(serializers.Serializer):
    term = serializers.CharField(max_length=150)


class SynonymCreateSerializer(SynonymUpdateSerializer):
    product = serializers.PrimaryKeyRelatedField(queryset=CatalogProduct.objects.all())


# --- Sorties -----------------------------------------------------------------------


class AdminZoneSerializer(serializers.ModelSerializer):
    parent_name = serializers.SerializerMethodField()
    active_children_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = Zone
        fields = ("id", "name", "level", "parent", "parent_name", "official_code", "order",
                  "latitude", "longitude", "is_active", "active_children_count", "updated_at")

    def get_parent_name(self, obj) -> str | None:
        return obj.parent.name if obj.parent_id else None


class AdminItemSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    code = serializers.CharField()
    name = serializers.CharField()
    icon = serializers.CharField()
    order = serializers.IntegerField()
    is_active = serializers.BooleanField()
    updated_at = serializers.DateTimeField()


class AdminSectorSerializer(AdminItemSerializer):
    active_children_count = serializers.IntegerField(
        read_only=True, help_text="Sous-catégories actives")


class AdminSubcategorySerializer(AdminItemSerializer):
    sector = serializers.IntegerField(source="sector_id")


class AdminProductSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    category = serializers.IntegerField(source="category_id", allow_null=True)
    category_name = serializers.SerializerMethodField()
    synonyms_count = serializers.IntegerField(read_only=True)
    is_active = serializers.BooleanField()
    updated_at = serializers.DateTimeField()

    def get_category_name(self, obj) -> str | None:
        return obj.category.name if obj.category_id else None


class AdminSynonymSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    product = serializers.IntegerField(source="product_id")
    product_name = serializers.SerializerMethodField()
    term = serializers.CharField()
    is_active = serializers.BooleanField()
    updated_at = serializers.DateTimeField()

    def get_product_name(self, obj) -> str:
        return obj.product.name


class FreeValueSerializer(serializers.Serializer):
    value = serializers.CharField(help_text="Forme la plus fréquente saisie")
    normalized = serializers.CharField(help_text="Minuscules, sans accents")
    count = serializers.IntegerField(help_text="Nombre de commerces")


class FreeValuesSerializer(serializers.Serializer):
    secteur_libre = FreeValueSerializer(many=True)
    categorie_service_libre = FreeValueSerializer(many=True)
    structure_type_libre = FreeValueSerializer(many=True)
