"""Publications (T090).

Lecture : auteur = nom du commerce, zone, initiales/photo ; jamais de numéro ni de profil
complet. Écriture : `media` (clé de stockage de l'auteur, kind `post_image` ou `post_video`),
`caption`, `offer` (facultatif, une offre du MÊME commerce). Le commerce n'est jamais dans
le corps : c'est celui du compte connecté.
"""
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.business.models import Offer
from apps.business.serializers.profile import validate_storage_key
from apps.business.services.storage_service import StorageError, get_storage, parse_key
from apps.forum.models import CAPTION_MAX, MediaType, Post
from apps.forum.serializers.comment import CommentSerializer
from apps.forum.serializers.common import initials, public_url

MEDIA_KINDS = {"post_image": MediaType.IMAGE, "post_video": MediaType.VIDEO}


class PostZoneSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()


class PostAuthorSerializer(serializers.Serializer):
    business_id = serializers.IntegerField()
    name = serializers.CharField()
    initials = serializers.CharField()
    photo = serializers.CharField(allow_null=True)
    zone = PostZoneSerializer()


class PostOfferSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()


class PostSerializer(serializers.ModelSerializer):
    author = serializers.SerializerMethodField()
    media_url = serializers.SerializerMethodField(help_text="Adresse publique de l'image/vidéo.")
    offer = serializers.SerializerMethodField(help_text="Produit associé ({id, name}) ou null.")
    comments_count = serializers.IntegerField(read_only=True)
    is_mine = serializers.SerializerMethodField()

    class Meta:
        model = Post
        fields = [
            "id", "author", "media_type", "media_url", "caption", "offer", "created_at",
            "comments_count", "is_mine",
        ]
        read_only_fields = fields

    @extend_schema_field(PostAuthorSerializer)
    def get_author(self, obj) -> dict:
        profile = obj.profile
        return {
            "business_id": profile.pk, "name": profile.name, "initials": initials(profile.name),
            "photo": public_url(profile.photo),
            "zone": {"id": profile.zone_id, "name": profile.zone.name},
        }

    def get_media_url(self, obj) -> str | None:
        return public_url(obj.media)

    @extend_schema_field(PostOfferSerializer(allow_null=True))
    def get_offer(self, obj) -> dict | None:
        return {"id": obj.offer_id, "name": obj.offer.name} if obj.offer_id else None

    def get_is_mine(self, obj) -> bool:
        request = self.context.get("request")
        return bool(request and obj.profile.owner_id == request.user.pk)


class MyPostSerializer(PostSerializer):
    """`GET /api/forum/mine/` : en plus, le statut (actif ou masqué par la modération)."""

    status = serializers.CharField(
        read_only=True, help_text="actif ou masque (masquée par la modération)."
    )

    class Meta(PostSerializer.Meta):
        fields = [*PostSerializer.Meta.fields, "status"]
        read_only_fields = fields


class PostDetailSerializer(PostSerializer):
    comments = serializers.SerializerMethodField(
        help_text="Commentaires paginés (page, page_size) : {count, next, previous, results}."
    )

    class Meta(PostSerializer.Meta):
        fields = [*PostSerializer.Meta.fields, "comments"]
        read_only_fields = fields

    @extend_schema_field(CommentSerializer(many=True))
    def get_comments(self, obj):
        return self.context["comments_page"]


class PostMediaField(serializers.CharField):
    """Clé de stockage du média : format serveur, propre au compte connecté, kind post_image ou
    post_video, fichier réellement envoyé. Les messages ne répètent jamais la clé."""

    default_validators = [validate_storage_key]

    def __init__(self, **kwargs):
        kwargs.setdefault("max_length", 255)
        super().__init__(**kwargs)

    def run_validation(self, data=serializers.empty):
        value = super().run_validation(data)
        user = getattr(self.context.get("request"), "user", None)
        try:
            parsed = parse_key(value)
        except StorageError:
            raise serializers.ValidationError("Fichier inconnu : envoyez-le d'abord.") from None
        if (
            user is None or not user.is_authenticated or parsed.owner_id != user.pk
            or parsed.kind not in MEDIA_KINDS or not get_storage().exists(value)
        ):
            raise serializers.ValidationError("Fichier inconnu : envoyez-le d'abord.")
        return value


class PostCreateSerializer(serializers.Serializer):
    media = PostMediaField(
        help_text="Clé de stockage de `POST /api/uploads/sign/` (kind post_image ou post_video). "
                  "Le type (image/vidéo) en est déduit par le serveur."
    )
    caption = serializers.CharField(
        max_length=CAPTION_MAX, required=False, allow_blank=True, default="",
        error_messages={"max_length": f"{CAPTION_MAX} caractères au maximum."},
        help_text="Légende, 500 caractères au plus ; texte brut stocké tel quel.",
    )
    offer = serializers.IntegerField(
        required=False, allow_null=True, default=None,
        help_text="Identifiant d'une de VOS offres (facultatif).",
    )

    def validate_offer(self, value):
        if value is None:
            return None
        profile = self.context["profile"]
        offer = Offer.objects.filter(pk=value, profile=profile).first()
        if offer is None:
            raise serializers.ValidationError("Produit introuvable.")
        return offer

    def validated_post_values(self) -> dict:
        data = self.validated_data
        kind = parse_key(data["media"]).kind
        return {
            "media": data["media"], "media_type": MEDIA_KINDS[kind],
            "caption": data["caption"], "offer": data["offer"],
        }
