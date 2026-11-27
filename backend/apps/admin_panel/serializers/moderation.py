"""Modération du forum (T094). Ni numéro en clair, ni identité des signalants."""
from rest_framework import serializers

from apps.admin_panel.serializers.account import masked
from apps.forum.models import ForbiddenWord, ReportReason, ReportTarget


class ReasonCountSerializer(serializers.Serializer):
    reason = serializers.ChoiceField(choices=ReportReason.choices)
    count = serializers.IntegerField(help_text="Nombre de signalements avec ce motif")


class ReportRowSerializer(serializers.Serializer):
    target_type = serializers.ChoiceField(choices=ReportTarget.choices)
    target_id = serializers.IntegerField()
    content_status = serializers.CharField(
        help_text="Publication/commentaire : actif, masque ou supprime. Commerce : statut de "
                  "son compte business (actif, en_attente_validation, rejete).")
    preview = serializers.CharField(
        help_text="Légende ou texte tronqué à 140 caractères (nom pour un commerce) ; numéros "
                  "et codes masqués.")
    media_type = serializers.CharField(
        allow_null=True, help_text="image/video pour une publication")
    post_id = serializers.IntegerField(allow_null=True, help_text="Publication d'un commentaire")
    business_id = serializers.IntegerField()
    business_name = serializers.CharField()
    author_id = serializers.SerializerMethodField(help_text="Compte auteur du contenu")
    author_name = serializers.CharField()
    author_phone_masked = serializers.SerializerMethodField(
        help_text="Ex. « +237 6•• •• •• 41 »")
    reasons = ReasonCountSerializer(many=True, help_text="Motifs agrégés, avec compteur")
    reporters_count = serializers.IntegerField(help_text="Nombre de signalants distincts")
    first_reported_at = serializers.DateTimeField()
    last_reported_at = serializers.DateTimeField()

    def get_author_id(self, obj) -> int:
        return obj["author"].pk

    def get_author_phone_masked(self, obj) -> str:
        return masked(obj["author"])


class ModerationActionSerializer(serializers.Serializer):
    reason = serializers.CharField(
        required=False, allow_blank=True, max_length=900,
        help_text="Motif. OBLIGATOIRE pour supprimer (400 reason_required), facultatif sinon.")


class ForbiddenWordSerializer(serializers.ModelSerializer):
    class Meta:
        model = ForbiddenWord
        fields = ["id", "word", "created_at"]
        read_only_fields = fields


class ForbiddenWordCreateSerializer(serializers.Serializer):
    word = serializers.CharField(
        help_text="Mot ou expression ; stocké sans accents ni majuscules (2 à 60 caractères).")


