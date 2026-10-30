"""Un résultat de recherche (T041).

Champs publics seulement. JAMAIS le numéro (`phone_anchor`), la CNI, le diplôme, le motif de
rejet. Pas de badge « abonné » : l'abonnement ne sert qu'à l'ordre des résultats.
"""
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.business.models import AccountType
from apps.business.services.storage_service import StorageError, get_storage

SERVICE_TYPES = (AccountType.PRESTATAIRE_SERVICE, AccountType.STRUCTURE)


class ZoneSummarySerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()


class SearchResultSerializer(serializers.Serializer):
    """Lit un `BusinessProfile` ; le contexte peut contenir `prices` = {id du profil: prix}."""

    id = serializers.IntegerField(help_text="Identifiant du compte business (fiche publique).")
    name = serializers.CharField()
    kind = serializers.SerializerMethodField(help_text="« produit » ou « service ».")
    secteur = serializers.SerializerMethodField(
        help_text="Nom du secteur (ou catégorie de service / type d'établissement)."
    )
    secteur_code = serializers.SerializerMethodField(
        help_text="Code stable du secteur ; null pour un prestataire ou une structure."
    )
    zone = serializers.SerializerMethodField()
    repere = serializers.CharField()
    description_activite = serializers.CharField(help_text="Sous-titre de la carte.")
    photo = serializers.SerializerMethodField(help_text="Adresse de la photo, ou null.")
    prix_indicatif = serializers.SerializerMethodField(
        help_text="Plus petit prix (FCFA) parmi les offres actives ; null = sur demande."
    )
    verifie = serializers.SerializerMethodField(help_text="Badge « ✓ Identité vérifiée ».")

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

    def get_photo(self, obj) -> str | None:
        if not obj.photo:
            return None
        try:
            return get_storage().public_url(obj.photo)
        except StorageError:
            return None

    def get_prix_indicatif(self, obj) -> int | None:
        return self.context.get("prices", {}).get(obj.pk)

    def get_verifie(self, obj) -> bool:
        return bool(obj.cni_verifiee)
