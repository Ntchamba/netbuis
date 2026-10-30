"""Offre du commerçant (T037) : lecture et écriture par son propriétaire.

`price_fcfa` : entier ≥ 0, ou `null` = « sur demande » (`on_request` en lecture).
`photos` : clés de stockage de `POST /api/uploads/sign/` (kind `photo`), 4 au plus, propres au
compte connecté. Aucun compteur. Le profil est toujours celui de l'utilisateur connecté.
"""
from rest_framework import serializers

from apps.business.models import MAX_PHOTOS, Offer
from apps.business.serializers.profile import StorageKeyField
from apps.catalog.models import CatalogProduct


class OfferSerializer(serializers.ModelSerializer):
    price_fcfa = serializers.IntegerField(
        min_value=0, max_value=2_000_000_000, allow_null=True, required=False,
        help_text="Prix en FCFA (entier ≥ 0) ; null = sur demande.",
    )
    photos = serializers.ListField(
        child=StorageKeyField(kind="photo", required=True, allow_blank=False),
        max_length=MAX_PHOTOS, required=False,
        error_messages={"max_length": f"{MAX_PHOTOS} photos au maximum."},
        help_text="Clés de stockage des photos (4 au plus).",
    )
    catalog_product = serializers.PrimaryKeyRelatedField(
        queryset=CatalogProduct.objects.filter(is_active=True), allow_null=True, required=False,
        help_text="Identifiant d'un produit du catalogue (facultatif).",
    )
    on_request = serializers.BooleanField(read_only=True)

    class Meta:
        model = Offer
        fields = [
            "id", "name", "description", "price_fcfa", "on_request", "photos",
            "catalog_product", "is_active", "created_at", "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    def validate_name(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Le nom est obligatoire.")
        return value
