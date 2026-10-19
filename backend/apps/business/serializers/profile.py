"""Compte business, vu par son PROPRIÉTAIRE (T026) : `POST /api/business/`,
`GET` et `PATCH /api/business/me/`.

Contrat du corps de requête (mêmes noms que le modèle) :
- référentiels et lieu par IDENTIFIANT entier, comme les routes zones et catalogue :
  `zone`, `secteur`, `categorie_service`, `structure_type`, `sous_categories` (liste d'ids) ;
- listes d'établissement par code stable : `rayons`, `equipements`, `specialites` ;
- photos et pièces : clés de stockage (chaînes) produites par `POST /api/uploads/sign/` (T027).
  Une clé n'est acceptée que si elle appartient au compte connecté, correspond au champ
  (`photo` ↔ kind photo…) et que le fichier existe dans le bon espace (privé pour la CNI et le
  diplôme).

Numéro : le client n'envoie JAMAIS `phone_anchor` (absent du contrat, ignoré s'il est envoyé) ;
le serveur ancre `owner.phone`, le numéro vérifié par SMS (voir `profile_service`).

Secrets : `cni_photo` est en ÉCRITURE SEULE. En lecture, le propriétaire reçoit
`phone_masked` (numéro masqué) et `has_cni` ; jamais le numéro entier ni le chemin de la CNI. Les
messages d'erreur ne répètent jamais la valeur fautive.
"""
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.business.models import Aisle, Amenity, BusinessProfile, Speciality
from apps.business.services.storage_service import StorageError, get_storage, parse_key
from apps.catalog.models import Sector, ServiceCategory, StructureType, Subcategory
from apps.core.utils.phone import mask_phone
from apps.geo.models import Zone


def validate_storage_key(value: str) -> str:
    """Chemin relatif : pas de `/` initial, pas de `\\`, pas de segment vide, `.` ou `..`,
    pas d'adresse (`://`). La propriété et l'existence sont contrôlées par `StorageKeyField`."""
    if value == "":
        return value
    segments = value.split("/")
    if (
        "\\" in value
        or "://" in value
        or any(ord(char) < 32 for char in value)
        or any(segment in ("", ".", "..") for segment in segments)
    ):
        raise serializers.ValidationError("Chemin de fichier invalide.")
    return value


class StorageKeyField(serializers.CharField):
    """Clé de stockage : format, puis PROPRIÉTÉ (la clé commence par `u<id du compte connecté>/`),
    nature (`kind` = `kind` du champ) et EXISTENCE du fichier dans le bon espace. Les messages ne
    répètent jamais la clé. Sans requête authentifiée dans le contexte : refus."""

    default_validators = [validate_storage_key]

    def __init__(self, *, kind: str, **kwargs):
        self.kind = kind
        kwargs.setdefault("required", False)
        kwargs.setdefault("allow_blank", True)
        kwargs.setdefault("max_length", 255)
        super().__init__(**kwargs)

    def run_validation(self, data=serializers.empty):
        value = super().run_validation(data)
        if value in ("", None, serializers.empty):
            return value
        request = self.context.get("request")
        user = getattr(request, "user", None)
        try:
            parsed = parse_key(value)
        except StorageError:
            raise serializers.ValidationError("Fichier inconnu : envoyez-le d'abord.") from None
        if (
            user is None or not user.is_authenticated
            or parsed.owner_id != user.pk
            or parsed.kind != self.kind
            or not get_storage().exists(value)
        ):
            raise serializers.ValidationError("Fichier inconnu : envoyez-le d'abord.")
        return value


class BusinessProfileSerializer(serializers.ModelSerializer):
    zone = serializers.PrimaryKeyRelatedField(
        queryset=Zone.objects.filter(is_active=True),
        help_text="Identifiant d'une ville/village ou d'un quartier (pas une région).",
    )
    secteur = serializers.PrimaryKeyRelatedField(
        queryset=Sector.objects.filter(is_active=True), required=False, allow_null=True,
        help_text="Identifiant du secteur (commerce, entreprise, particulier vendeur).",
    )
    categorie_service = serializers.PrimaryKeyRelatedField(
        queryset=ServiceCategory.objects.filter(is_active=True), required=False, allow_null=True,
        help_text="Identifiant de la catégorie de service (prestataire).",
    )
    structure_type = serializers.PrimaryKeyRelatedField(
        queryset=StructureType.objects.filter(is_active=True), required=False, allow_null=True,
        help_text="Identifiant du type de structure.",
    )
    sous_categories = serializers.PrimaryKeyRelatedField(
        queryset=Subcategory.objects.filter(is_active=True), many=True, required=False,
        help_text="Identifiants de sous-catégories du secteur ; 3 au plus sans abonnement.",
    )
    rayons = serializers.ListField(
        child=serializers.ChoiceField(choices=Aisle.choices), required=False,
        help_text="Supermarché : 3 au plus sans abonnement.",
    )
    equipements = serializers.ListField(
        child=serializers.ChoiceField(choices=Amenity.choices), required=False,
    )
    specialites = serializers.ListField(
        child=serializers.ChoiceField(choices=Speciality.choices), required=False,
        help_text="Centre de santé : 3 au plus sans abonnement.",
    )
    photo = StorageKeyField(
        kind="photo", help_text="Clé de stockage de la photo du commerce (facultative).")
    representant_photo = StorageKeyField(
        kind="representant_photo", help_text="Clé de stockage de la photo du représentant.")
    diplome_photo = StorageKeyField(
        kind="diplome_photo", help_text="Clé de stockage PRIVÉE du diplôme (facultatif)."
    )
    cni_photo = StorageKeyField(
        kind="cni_photo", write_only=True,
        help_text="Clé de stockage PRIVÉE de la CNI. Jamais renvoyée.",
    )
    phone_masked = serializers.SerializerMethodField(
        help_text="Numéro masqué : seuls le premier et les deux derniers chiffres restent"
    )
    has_cni = serializers.SerializerMethodField(help_text="Vrai si une CNI a été envoyée")

    class Meta:
        model = BusinessProfile
        fields = (
            "id", "type_compte", "name", "zone", "repere", "description", "photo",
            "representant_nom", "representant_photo", "phone_masked",
            "whatsapp_available", "status", "motif_rejet",
            "forme_juridique", "rccm",
            "categorie_service", "categorie_service_libre", "cni_photo", "has_cni",
            "cni_verifiee", "diplome_photo",
            "structure_type", "structure_type_libre", "rayons", "cuisine", "livraison",
            "horaires", "standing", "nombre_chambres", "equipements", "numero_agrement",
            "specialites",
            "secteur", "secteur_libre", "sous_categories", "description_activite",
            "calls_count", "views_count", "created_at", "updated_at",
        )
        read_only_fields = (
            "id", "status", "motif_rejet", "cni_verifiee", "calls_count", "views_count",
            "created_at", "updated_at",
        )

    def validate_sous_categories(self, value):
        return list(dict.fromkeys(value))  # sans doublon, ordre conservé

    @extend_schema_field(serializers.CharField())
    def get_phone_masked(self, obj) -> str:
        try:
            return mask_phone(obj.phone_anchor)
        except ValueError:
            return ""

    def get_has_cni(self, obj) -> bool:
        return bool(obj.cni_photo)
