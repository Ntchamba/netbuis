"""Fiche publique d'un commerce (T047b) : champs publics seulement.

JAMAIS : le numéro (`phone_anchor`), la CNI, le diplôme (seulement `diplome_fourni`), le motif
de rejet, le numéro WhatsApp (seulement `whatsapp_available`), les compteurs.
"""
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.business.models import AccountType, BusinessProfile, Offer
from apps.business.models.profile import STRUCTURE_DETAIL_FIELDS
from apps.business.services.storage_service import StorageError, get_storage
from apps.search.serializers.result import SERVICE_TYPES, ZoneSummarySerializer


def _public_url(key: str) -> str | None:
    if not key:
        return None
    try:
        return get_storage().public_url(key)
    except StorageError:
        return None


class PublicOfferSerializer(serializers.ModelSerializer):
    on_request = serializers.BooleanField(read_only=True)
    photos = serializers.SerializerMethodField(help_text="Adresses des photos.")

    class Meta:
        model = Offer
        fields = ["id", "name", "description", "price_fcfa", "on_request", "photos"]

    def get_photos(self, obj) -> list[str]:
        return [url for url in map(_public_url, obj.photos) if url]


class PublicBusinessSerializer(serializers.ModelSerializer):
    kind = serializers.SerializerMethodField(help_text="« produit » ou « service ».")
    secteur = serializers.SerializerMethodField(
        help_text="Nom du secteur (ou catégorie de service / type d'établissement)."
    )
    secteur_code = serializers.SerializerMethodField()
    zone = serializers.SerializerMethodField()
    photos = serializers.SerializerMethodField(help_text="Adresses des photos du commerce.")
    verifie = serializers.SerializerMethodField(help_text="Badge « ✓ Identité vérifiée ».")
    forme_juridique = serializers.SerializerMethodField(help_text="Entreprise seulement.")
    diplome_fourni = serializers.SerializerMethodField(
        help_text="Prestataire : vrai si un diplôme a été fourni (le fichier n'est pas exposé)."
    )
    structure_type = serializers.SerializerMethodField()
    details = serializers.SerializerMethodField(
        help_text="Détails de structure propres au type (cuisine, horaires, livraison, "
        "standing, chambres, équipements, rayons, spécialités) ; vide sinon."
    )
    offers = serializers.SerializerMethodField(help_text="Produits/services actifs.")

    class Meta:
        model = BusinessProfile
        fields = (
            "id", "name", "type_compte", "kind", "secteur", "secteur_code", "zone", "repere",
            "description", "description_activite", "photos", "verifie", "whatsapp_available",
            "forme_juridique", "diplome_fourni", "structure_type", "details", "offers",
        )

    def get_kind(self, obj) -> str:
        return "service" if obj.type_compte in SERVICE_TYPES else "produit"

    def get_secteur(self, obj) -> str:
        if obj.secteur_id:
            return obj.secteur.name
        if obj.categorie_service_id:
            return obj.categorie_service.name
        if obj.structure_type_id:
            return obj.structure_type.name
        return obj.secteur_libre or obj.categorie_service_libre or obj.structure_type_libre

    def get_secteur_code(self, obj) -> str | None:
        return obj.secteur.code if obj.secteur_id else None

    @extend_schema_field(ZoneSummarySerializer)
    def get_zone(self, obj) -> dict:
        return {"id": obj.zone_id, "name": obj.zone.name}

    def get_photos(self, obj) -> list[str]:
        url = _public_url(obj.photo)
        return [url] if url else []

    def get_verifie(self, obj) -> bool:
        return bool(obj.cni_verifiee)

    def get_forme_juridique(self, obj) -> str:
        return obj.forme_juridique if obj.type_compte == AccountType.ENTREPRISE else ""

    def get_diplome_fourni(self, obj) -> bool:
        return obj.type_compte == AccountType.PRESTATAIRE_SERVICE and bool(obj.diplome_photo)

    def get_structure_type(self, obj) -> str:
        if obj.type_compte != AccountType.STRUCTURE:
            return ""
        return obj.structure_type.name if obj.structure_type_id else obj.structure_type_libre

    @extend_schema_field(serializers.DictField())
    def get_details(self, obj) -> dict:
        if obj.type_compte != AccountType.STRUCTURE or not obj.structure_type_id:
            return {}
        details = {}
        for field in STRUCTURE_DETAIL_FIELDS.get(obj.structure_type.code, ()):
            if field == "numero_agrement":
                continue  # administratif : non public
            value = getattr(obj, field)
            if value not in ("", None, []):
                details[field] = value
        return details

    @extend_schema_field(PublicOfferSerializer(many=True))
    def get_offers(self, obj) -> list:
        offers = [o for o in obj.offers.all() if o.is_active]
        return PublicOfferSerializer(offers, many=True, context=self.context).data
