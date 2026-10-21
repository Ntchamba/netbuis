"""Paramètres de la recherche (T041) : `q`, `zone`, `sector`.

`q` peut être vide (liste de l'Accueil). `zone` : identifiant d'une zone active (la recherche
inclut les zones qu'elle contient). `sector` : code stable du secteur (ou son identifiant).
La page vient de `?page=` (pagination standard, 20 par page).
"""
from rest_framework import serializers

from apps.catalog.services.normalize import MAX_QUERY_LENGTH
from apps.geo.models import Zone


class SearchQuerySerializer(serializers.Serializer):
    q = serializers.CharField(
        required=False, allow_blank=True, max_length=MAX_QUERY_LENGTH, default="",
        help_text="Texte cherché ; vide = les commerces de la zone (abonnés d'abord).",
    )
    zone = serializers.PrimaryKeyRelatedField(
        queryset=Zone.objects.filter(is_active=True), required=False, allow_null=True,
        default=None,
        help_text="Identifiant de la ville, du quartier… (inclut ce qu'elle contient).",
    )
    sector = serializers.CharField(
        required=False, allow_blank=True, default="",
        help_text="Code stable du secteur (ex. alimentation).",
    )

    def validate_sector(self, value):
        value = value.strip()
        return int(value) if value.isdigit() else value


class VoiceQuerySerializer(SearchQuerySerializer):
    """Recherche vocale : `text` = phrase reconnue par le téléphone (`q` n'est pas utilisé)."""

    text = serializers.CharField(
        max_length=MAX_QUERY_LENGTH * 3, allow_blank=True,
        help_text="Texte reconnu par le téléphone, ex. « je cherche du riz à Akwa ».",
    )
    q = None
