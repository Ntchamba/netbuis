"""Sérialiseurs de la carte (T060). Aucun numéro de téléphone ni pièce d'identité."""
from rest_framework import serializers


class MapNodeSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    explorable = serializers.BooleanField(
        help_text="Vrai seulement si cette zone contient une ville avec un commerce actif."
    )


class MapDepartementSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    explorable = serializers.BooleanField()


class MapRegionSerializer(MapDepartementSerializer):
    departements = MapDepartementSerializer(many=True)


class MapZoneRefSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()


class MapCitySerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    latitude = serializers.FloatField(allow_null=True)
    longitude = serializers.FloatField(allow_null=True)
    businesses_count = serializers.IntegerField(help_text="Commerces actifs (ville + quartiers).")
    region = MapNodeSerializer(allow_null=True)
    departement = MapNodeSerializer(allow_null=True)


class MapCitiesSerializer(serializers.Serializer):
    cities = MapCitySerializer(many=True)
    regions = MapRegionSerializer(many=True)


class MapAreaSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    businesses_count = serializers.IntegerField()
    products_count = serializers.IntegerField(help_text="Offres actives référencées.")


class MapAreasSerializer(serializers.Serializer):
    city = MapZoneRefSerializer()
    areas = MapAreaSerializer(many=True)
    businesses_without_area = serializers.IntegerField(
        help_text="Commerces rattachés à la ville elle-même, sans quartier."
    )
