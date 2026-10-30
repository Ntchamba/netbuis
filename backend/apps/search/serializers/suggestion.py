"""Une suggestion pendant la frappe (T041)."""
from rest_framework import serializers


class SuggestionSerializer(serializers.Serializer):
    text = serializers.CharField(help_text="Texte à proposer (et à chercher si on le choisit).")
    type = serializers.ChoiceField(
        choices=["produit", "recherche"],
        help_text="« produit » : du catalogue ; « recherche » : terme souvent cherché.",
    )
