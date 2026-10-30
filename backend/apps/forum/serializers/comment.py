"""Commentaires (T090). Auteur = nom du commerce (s'il en a un d'actif) sinon « Prénom I. »."""
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.business.models import BusinessStatus
from apps.forum.models import COMMENT_MAX, Comment
from apps.forum.serializers.common import initials, public_url, short_name


class CommentAuthorSerializer(serializers.Serializer):
    name = serializers.CharField()
    initials = serializers.CharField()
    photo = serializers.CharField(allow_null=True)
    is_business = serializers.BooleanField()


class CommentSerializer(serializers.ModelSerializer):
    author = serializers.SerializerMethodField()
    is_mine = serializers.SerializerMethodField(help_text="Vrai si le commentaire est le vôtre.")

    class Meta:
        model = Comment
        fields = ["id", "author", "text", "created_at", "is_mine"]
        read_only_fields = fields

    @extend_schema_field(CommentAuthorSerializer)
    def get_author(self, obj) -> dict:
        user = obj.author
        profile = getattr(user, "business_profile", None)
        if profile is not None and profile.status == BusinessStatus.ACTIVE:
            return {
                "name": profile.name, "initials": initials(profile.name),
                "photo": public_url(profile.photo), "is_business": True,
            }
        name = short_name(user.name)
        return {"name": name, "initials": initials(name), "photo": None, "is_business": False}

    def get_is_mine(self, obj) -> bool:
        request = self.context.get("request")
        return bool(request and obj.author_id == request.user.pk)


class CommentCreateSerializer(serializers.Serializer):
    text = serializers.CharField(
        max_length=COMMENT_MAX,
        error_messages={
            "blank": "Écrivez un commentaire.",
            "max_length": f"{COMMENT_MAX} caractères au maximum.",
        },
        help_text="Texte brut, 300 caractères au plus ; stocké tel quel, jamais interprété.",
    )
