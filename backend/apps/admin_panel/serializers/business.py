"""File d'attente des demandes de compte business (T071, zone sensible).

Le numéro est toujours MASQUÉ. Les pièces privées (CNI, diplôme) ne sont jamais des clés de
stockage : seulement une URL temporaire liée à l'administrateur qui fait la requête.
"""
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.business.models import BusinessProfile
from apps.business.services.storage_service import StorageError, get_storage
from apps.core.utils.phone import mask_phone


def _public_url(key: str):
    if not key:
        return None
    try:
        return get_storage().public_url(key)
    except StorageError:
        return None


class BusinessRequestSerializer(serializers.ModelSerializer):
    type = serializers.SerializerMethodField(help_text="Toujours « business »")
    owner_id = serializers.IntegerField(read_only=True)
    owner_name = serializers.CharField(source="owner.name", read_only=True)
    phone_masked = serializers.SerializerMethodField(help_text="Ex. « +237 6•• •• •• 12 »")
    zone_name = serializers.CharField(source="zone.name", read_only=True)
    categorie_service_name = serializers.SerializerMethodField()
    photo_url = serializers.SerializerMethodField()
    representant_photo_url = serializers.SerializerMethodField()
    cni_url = serializers.SerializerMethodField(
        help_text="URL temporaire (5 min) liée à l'administrateur ; prestataire seulement"
    )
    diplome_url = serializers.SerializerMethodField(
        help_text="URL temporaire (5 min) liée à l'administrateur ; si un diplôme a été envoyé"
    )

    class Meta:
        model = BusinessProfile
        fields = (
            "id", "type", "type_compte", "name", "status", "owner_id", "owner_name",
            "phone_masked", "zone", "zone_name", "repere", "description",
            "representant_nom", "forme_juridique", "rccm", "categorie_service",
            "categorie_service_name", "categorie_service_libre", "cni_verifiee",
            "photo_url", "representant_photo_url", "cni_url", "diplome_url", "created_at",
        )
        read_only_fields = fields

    def get_type(self, obj) -> str:
        return "business"

    @extend_schema_field(serializers.CharField())
    def get_phone_masked(self, obj) -> str:
        try:
            return mask_phone(obj.phone_anchor)
        except ValueError:
            return ""

    @extend_schema_field(serializers.CharField(allow_null=True))
    def get_categorie_service_name(self, obj):
        return obj.categorie_service.name if obj.categorie_service_id else None

    @extend_schema_field(serializers.CharField(allow_null=True))
    def get_photo_url(self, obj):
        return _public_url(obj.photo)

    @extend_schema_field(serializers.CharField(allow_null=True))
    def get_representant_photo_url(self, obj):
        return _public_url(obj.representant_photo)

    def _private_url(self, key: str):
        if not key:
            return None
        try:
            return get_storage().private_download_url(
                key, admin_id=self.context["request"].user.pk
            )
        except StorageError:
            return None

    @extend_schema_field(serializers.CharField(allow_null=True))
    def get_cni_url(self, obj):
        return self._private_url(obj.cni_photo)

    @extend_schema_field(serializers.CharField(allow_null=True))
    def get_diplome_url(self, obj):
        return self._private_url(obj.diplome_photo)


class RejectSerializer(serializers.Serializer):
    reason = serializers.CharField(
        required=False, allow_blank=True, trim_whitespace=True,
        help_text="Motif du rejet (obligatoire, 1000 caractères au plus). Lu par le commerçant.",
    )


class RequestDecisionSerializer(serializers.Serializer):
    """Réponse de approve / reject : l'état du dossier après décision."""

    id = serializers.IntegerField()
    status = serializers.CharField()
    cni_verifiee = serializers.BooleanField()
    motif_rejet = serializers.CharField()
