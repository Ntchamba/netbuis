"""BusinessProfile : le compte business (un par compte, au plus) — T025,
docs/spec/MODELE_DONNEES.md § BusinessProfile.

Règles tenues ici (clean() ET save(), comme Zone) :
- les champs propres à un type de compte sont vides pour les autres types ;
- secteur, sous-catégories et description d'activité sont interdits au prestataire et à la
  structure ;
- les détails d'établissement dépendent du type de structure (code stable du référentiel) ;
- le lieu est une ville/village ou un quartier.

Ce qui n'est PAS ici (volontairement) :
- les plafonds de 3 (sous-catégories, rayons, spécialités) : ils dépendent de l'abonnement
  (`is_subscribed`, T025b) et sont appliqués par `services/profile_service` (T026) ;
- l'envoi des fichiers : `photo`, `representant_photo`, `cni_photo`, `diplome_photo` sont des
  clés de stockage (chemin relatif) remplies par `StorageService` (T027).

`phone_anchor` (numéro du commerçant) et `cni_photo` ne doivent figurer dans aucun sérialiseur
destiné à l'application ; le numéro ne sort que de `POST /api/calls/initiate/`.
"""
from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from django.db.models.signals import m2m_changed
from django.dispatch import receiver

from apps.core.models.base import TimeStampedModel
from apps.core.utils.phone import normalize_phone
from apps.geo.models import Zone, ZoneLevel

OTHER_CODE = "autre"  # code stable de la ligne « Autre » des référentiels


class AccountType(models.TextChoices):
    BOUTIQUE = "boutique", "Commerce"
    ENTREPRISE = "entreprise", "Entreprise"
    PARTICULIER_VENDEUR = "particulier_vendeur", "Particulier vendeur"
    PRESTATAIRE_SERVICE = "prestataire_service", "Prestataire de service"
    STRUCTURE = "structure", "Structure"


class BusinessStatus(models.TextChoices):
    PENDING = "en_attente_validation", "En attente de validation"
    ACTIVE = "actif", "Actif"  # valeur lue par apps.accounts.permissions
    REJECTED = "rejete", "Rejeté"


class LegalForm(models.TextChoices):
    INDIVIDUELLE = "individuelle", "Entreprise individuelle"
    SARL = "sarl", "SARL"
    SARLU = "sarlu", "SARLU"
    SA = "sa", "SA"
    GIC_COOPERATIVE = "gic_cooperative", "GIC / Coopérative"
    ASSOCIATION = "association", "Association"
    ETABLISSEMENT_PUBLIC = "etablissement_public", "Établissement public"
    AUTRE = "autre", "Autre"


class Aisle(models.TextChoices):
    """Rayons d'un supermarché."""

    ALIMENTATION_GENERALE = "alimentation_generale", "Alimentation générale"
    PRODUITS_FRAIS = "produits_frais", "Produits frais"
    BOISSONS = "boissons", "Boissons"
    HYGIENE_BEAUTE = "hygiene_beaute", "Hygiène & Beauté"
    ENTRETIEN_MAISON = "entretien_maison", "Entretien & Maison"
    BAZAR_ELECTROMENAGER = "bazar_electromenager", "Bazar & Électroménager"
    PRODUITS_BEBES = "produits_bebes", "Produits pour bébés"
    AUTRE = "autre", "Autre"


class Cuisine(models.TextChoices):
    CAMEROUNAISE = "camerounaise", "Camerounaise"
    AFRICAINE_AUTRE_PAYS = "africaine_autre_pays", "Africaine — autre pays"
    FAST_FOOD = "fast_food", "Fast-food"
    PIZZERIA_OCCIDENTALE = "pizzeria_occidentale", "Pizzeria/Occidentale"
    AUTRE = "autre", "Autre"


class Standing(models.TextChoices):
    ECONOMIQUE = "economique", "Économique"
    STANDARD = "standard", "Standard"
    CONFORT = "confort", "Confort"
    HAUT_STANDING = "haut_standing", "Haut standing"


class Amenity(models.TextChoices):
    PETIT_DEJEUNER = "petit_dejeuner", "Petit-déjeuner"
    WIFI = "wifi", "Wifi"
    PARKING = "parking", "Parking"
    CLIMATISATION = "climatisation", "Climatisation"


class Speciality(models.TextChoices):
    MEDECINE_GENERALE = "medecine_generale", "Médecine générale"
    PEDIATRIE = "pediatrie", "Pédiatrie"
    GYNECOLOGIE = "gynecologie", "Gynécologie"
    DENTISTERIE = "dentisterie", "Dentisterie"
    LABORATOIRE = "laboratoire", "Laboratoire d'analyses"
    PHARMACIE_INTERNE = "pharmacie_interne", "Pharmacie interne"
    AUTRE = "autre", "Autre"


# Types de compte qui ont un secteur, des sous-catégories et une description d'activité.
SECTOR_TYPES = (
    AccountType.BOUTIQUE, AccountType.ENTREPRISE, AccountType.PARTICULIER_VENDEUR,
)

# Codes stables des types de structure (apps/catalog/data/categories.json) -> champs de détail.
STRUCTURE_DETAIL_FIELDS = {
    "supermarche": ("rayons",),
    "restaurant": ("cuisine", "livraison", "horaires"),
    "hotel": ("standing", "nombre_chambres", "equipements"),
    "sante": ("numero_agrement", "specialites"),
}
ALL_STRUCTURE_DETAIL_FIELDS = tuple(
    name for names in STRUCTURE_DETAIL_FIELDS.values() for name in names
)
LIST_FIELD_CHOICES = {
    "rayons": Aisle,
    "equipements": Amenity,
    "specialites": Speciality,
}

ZONE_LEVELS_ALLOWED = (ZoneLevel.VILLE_VILLAGE, ZoneLevel.QUARTIER)


def validate_anchor_phone(value: str) -> None:
    """Mobile camerounais en E.164 exact (+2376XXXXXXXX)."""
    try:
        normalized = normalize_phone(value)
    except ValueError as exc:
        raise ValidationError("Numéro de téléphone camerounais invalide.") from exc
    if normalized != value:
        raise ValidationError("Le numéro doit être au format +2376XXXXXXXX.")


class BusinessProfileQuerySet(models.QuerySet):
    def visible(self):
        """Les comptes business que le public peut voir : l'UNIQUE définition de la visibilité.

        `actif` ET propriétaire utilisable (ni supprimé, ni bloqué, ni inactif). Recherche,
        carte, liste, fiche publique, tendances et appels doivent partir de ce queryset ;
        un profil en attente, rejeté ou dont le compte est supprimé/bloqué n'y est jamais.
        (Le propriétaire lit son propre profil par `/api/business/me/`, pas par ici.)
        """
        return self.filter(
            status=BusinessStatus.ACTIVE,
            owner__is_active=True, owner__is_blocked=False, owner__is_deleted=False,
        )


def _empty(value) -> bool:
    return value is None or value is False or value in ("", [], {})


class BusinessProfile(TimeStampedModel):
    owner = models.OneToOneField(
        settings.AUTH_USER_MODEL, verbose_name="compte", on_delete=models.CASCADE,
        related_name="business_profile",
    )
    type_compte = models.CharField("type de compte", max_length=24, choices=AccountType.choices)
    name = models.CharField("nom affiché", max_length=150)
    zone = models.ForeignKey(
        Zone, verbose_name="lieu", on_delete=models.PROTECT, related_name="business_profiles",
        help_text="Ville/village ou quartier.",
    )
    repere = models.CharField(
        "repère", max_length=150, blank=True, default="",
        help_text="Ex. « À côté du Grand Manguier ».",
    )
    description = models.TextField("description", blank=True, default="", max_length=1000)
    photo = models.CharField("photo (clé de stockage)", max_length=255, blank=True, default="")
    representant_nom = models.CharField(
        "nom du représentant", max_length=150, blank=True, default=""
    )
    representant_photo = models.CharField(
        "photo du représentant (clé de stockage)", max_length=255, blank=True, default=""
    )
    phone_anchor = models.CharField(
        "numéro ancré", max_length=16, blank=True, default="", validators=[validate_anchor_phone],
        help_text="Jamais exposé : ne sort que de POST /api/calls/initiate/.",
    )
    whatsapp_available = models.BooleanField("WhatsApp disponible", default=True)
    status = models.CharField(
        "statut", max_length=24, choices=BusinessStatus.choices, default=BusinessStatus.PENDING
    )
    motif_rejet = models.TextField("motif du rejet", blank=True, default="")

    # Entreprise
    forme_juridique = models.CharField(
        "forme juridique", max_length=24, choices=LegalForm.choices, blank=True, default=""
    )
    rccm = models.CharField("RCCM", max_length=50, blank=True, default="")

    # Prestataire de service
    categorie_service = models.ForeignKey(
        "catalog.ServiceCategory", verbose_name="catégorie de service", null=True, blank=True,
        on_delete=models.PROTECT, related_name="business_profiles",
    )
    categorie_service_libre = models.CharField(
        "catégorie de service (libre)", max_length=100, blank=True, default=""
    )
    cni_photo = models.CharField(
        "CNI (clé de stockage privée)", max_length=255, blank=True, default="",
        help_text="Espace privé. Jamais renvoyée à l'application.",
    )
    cni_verifiee = models.BooleanField("CNI vérifiée", default=False)
    diplome_photo = models.CharField(
        "diplôme (clé de stockage privée)", max_length=255, blank=True, default=""
    )

    # Structure
    structure_type = models.ForeignKey(
        "catalog.StructureType", verbose_name="type de structure", null=True, blank=True,
        on_delete=models.PROTECT, related_name="business_profiles",
    )
    structure_type_libre = models.CharField(
        "type de structure (libre)", max_length=100, blank=True, default=""
    )
    rayons = models.JSONField("rayons", blank=True, default=list)  # supermarché
    cuisine = models.CharField(  # restaurant
        "cuisine", max_length=24, choices=Cuisine.choices, blank=True, default=""
    )
    livraison = models.BooleanField("livraison", null=True, blank=True, default=None)  # restaurant
    horaires = models.CharField("horaires", max_length=200, blank=True, default="")  # restaurant
    standing = models.CharField(  # hôtel
        "standing", max_length=16, choices=Standing.choices, blank=True, default=""
    )
    nombre_chambres = models.PositiveIntegerField("nombre de chambres", null=True, blank=True)
    equipements = models.JSONField("équipements", blank=True, default=list)  # hôtel
    numero_agrement = models.CharField(  # centre de santé
        "numéro d'agrément sanitaire", max_length=50, blank=True, default=""
    )
    specialites = models.JSONField("spécialités", blank=True, default=list)  # centre de santé

    # Commerce, entreprise, particulier vendeur
    secteur = models.ForeignKey(
        "catalog.Sector", verbose_name="secteur", null=True, blank=True,
        on_delete=models.PROTECT, related_name="business_profiles",
    )
    secteur_libre = models.CharField("secteur (libre)", max_length=100, blank=True, default="")
    sous_categories = models.ManyToManyField(
        "catalog.Subcategory", verbose_name="sous-catégories", blank=True,
        related_name="business_profiles",
    )
    description_activite = models.TextField(
        "description de l'activité", blank=True, default="", max_length=500
    )

    # Compteurs : modifiés par le code seulement (appels : T047b, vues : T050).
    calls_count = models.PositiveIntegerField("appels lancés", default=0, editable=False)
    views_count = models.PositiveIntegerField("vues de la fiche", default=0, editable=False)

    objects = BusinessProfileQuerySet.as_manager()

    class Meta:
        verbose_name = "compte business"
        verbose_name_plural = "comptes business"
        ordering = ["-created_at", "id"]
        indexes = [
            models.Index(fields=["status"], name="business_profile_status_idx"),
            models.Index(fields=["zone", "status"], name="business_profile_zone_st_idx"),
            models.Index(fields=["type_compte"], name="business_profile_type_idx"),
        ]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(type_compte="entreprise")
                | (models.Q(forme_juridique="") & models.Q(rccm="")),
                name="business_profile_legal_only_company",
            ),
            models.CheckConstraint(
                condition=models.Q(type_compte="prestataire_service")
                | (
                    models.Q(cni_photo="", diplome_photo="", cni_verifiee=False,
                             categorie_service__isnull=True, categorie_service_libre="")
                ),
                name="business_profile_provider_fields",
            ),
            models.CheckConstraint(
                condition=models.Q(type_compte="structure")
                | (models.Q(structure_type__isnull=True) & models.Q(structure_type_libre="")),
                name="business_profile_structure_fields",
            ),
            models.CheckConstraint(
                condition=models.Q(
                    type_compte__in=["boutique", "entreprise", "particulier_vendeur"]
                )
                | (
                    models.Q(secteur__isnull=True, secteur_libre="", description_activite="")
                ),
                name="business_profile_sector_forbidden",
            ),
            models.CheckConstraint(
                condition=models.Q(status="rejete") | models.Q(motif_rejet=""),
                name="business_profile_reason_if_rejected",
            ),
        ]

    def __str__(self) -> str:
        # Jamais le numéro ancré.
        return f"{self.name} ({self.get_type_compte_display()})"

    # --- Validation ----------------------------------------------------------------------

    def clean(self):
        """Règles du modèle. Un profil n'existe qu'une fois soumis : il naît en
        `en_attente_validation`, donc représentant (nom et photo), numéro (et CNI du
        prestataire) sont exigés dès l'enregistrement — pas d'état « brouillon » côté serveur.
        La photo du commerce est FACULTATIVE (maquette CreationBusiness-Infos)."""
        errors: dict[str, str] = {}
        self._check_common(errors)
        if self.type_compte in AccountType.values:
            self._check_by_type(errors)
        self._check_lists(errors)
        if errors:
            raise ValidationError(errors)

    def _check_common(self, errors):
        if self.type_compte not in AccountType.values:
            errors["type_compte"] = "Type de compte inconnu."
        if not (self.name or "").strip():
            errors["name"] = "Le nom affiché est obligatoire."
        if self.zone_id is None:
            errors["zone"] = "Le lieu est obligatoire."
        elif self.zone.level not in ZONE_LEVELS_ALLOWED:
            errors["zone"] = "Le lieu doit être une ville, un village ou un quartier."
        for field, message in (
            ("representant_nom", "Le nom du représentant est obligatoire."),
            ("representant_photo", "La photo du représentant est obligatoire."),
            ("phone_anchor", "Le numéro est obligatoire."),
        ):
            if not (getattr(self, field) or "").strip():
                errors[field] = message
        if self.phone_anchor and "phone_anchor" not in errors:
            try:
                validate_anchor_phone(self.phone_anchor)
            except ValidationError as exc:
                errors["phone_anchor"] = exc.messages[0]
        if self.status not in BusinessStatus.values:
            errors["status"] = "Statut inconnu."
        if self.motif_rejet and self.status != BusinessStatus.REJECTED:
            errors["motif_rejet"] = "Le motif n'existe que pour un compte rejeté."

    def _forbid(self, errors, fields, message):
        for field in fields:
            if not _empty(getattr(self, field)):
                errors.setdefault(field, message)

    def _check_by_type(self, errors):
        kind = self.type_compte
        if kind != AccountType.ENTREPRISE:
            self._forbid(errors, ("forme_juridique", "rccm"), "Réservé aux entreprises.")
        elif not self.forme_juridique:
            errors["forme_juridique"] = "La forme juridique est obligatoire."

        if kind == AccountType.PRESTATAIRE_SERVICE:
            self._check_provider(errors)
        else:
            self._forbid(
                errors,
                ("categorie_service", "categorie_service_libre", "cni_photo", "diplome_photo"),
                "Réservé aux prestataires de service.",
            )
            if self.cni_verifiee:
                errors["cni_verifiee"] = "Réservé aux prestataires de service."

        if kind == AccountType.STRUCTURE:
            self._check_structure(errors)
        else:
            self._forbid(
                errors, ("structure_type", "structure_type_libre", *ALL_STRUCTURE_DETAIL_FIELDS),
                "Réservé aux structures.",
            )

        if kind in SECTOR_TYPES:
            self._check_sector(errors)
        else:
            self._forbid(
                errors, ("secteur", "secteur_libre", "description_activite"),
                "Les prestataires et les structures n'ont pas de secteur.",
            )

    def _check_provider(self, errors):
        if self.categorie_service_id is None:
            errors["categorie_service"] = "La catégorie de service est obligatoire."
        elif self.categorie_service.code != OTHER_CODE and self.categorie_service_libre:
            errors["categorie_service_libre"] = "Seulement pour la catégorie « Autre »."
        elif self.categorie_service.code == OTHER_CODE and not self.categorie_service_libre.strip():
            errors["categorie_service_libre"] = "Précisez la catégorie de service."
        if not self.cni_photo:
            errors["cni_photo"] = "La photo de la CNI est obligatoire."

    def _check_structure(self, errors):
        if self.structure_type_id is None:
            errors["structure_type"] = "Le type d'établissement est obligatoire."
            allowed = ()
        else:
            code = self.structure_type.code
            allowed = STRUCTURE_DETAIL_FIELDS.get(code, ())
            if code != OTHER_CODE and self.structure_type_libre:
                errors["structure_type_libre"] = "Seulement pour le type « Autre »."
            elif code == OTHER_CODE and not self.structure_type_libre.strip():
                errors["structure_type_libre"] = "Précisez le type d'établissement."
        for field in ALL_STRUCTURE_DETAIL_FIELDS:
            if field in allowed:
                continue
            value = getattr(self, field)
            if not _empty(value):
                errors[field] = "Ne correspond pas au type d'établissement choisi."

    def _check_sector(self, errors):
        if self.secteur_id is None:
            errors["secteur"] = "Le secteur est obligatoire."
        elif self.secteur.code != OTHER_CODE and self.secteur_libre:
            errors["secteur_libre"] = "Seulement pour le secteur « Autre »."
        elif self.secteur.code == OTHER_CODE and not self.secteur_libre.strip():
            errors["secteur_libre"] = "Précisez le secteur."

    def _check_lists(self, errors):
        for field, choices in LIST_FIELD_CHOICES.items():
            values = getattr(self, field)
            if not isinstance(values, list):
                errors[field] = "Doit être une liste."
            elif any(v not in choices.values for v in values):
                errors[field] = "Valeur inconnue dans la liste."
            elif len(set(values)) != len(values):
                errors[field] = "Une valeur est répétée."
        if self.nombre_chambres is not None and self.nombre_chambres < 1:
            errors["nombre_chambres"] = "Au moins une chambre."

    def save(self, *args, **kwargs):
        self.clean()
        super().save(*args, **kwargs)


def validate_subcategories(profile: "BusinessProfile", subcategories) -> None:
    """Un M2M ne peut pas être validé dans clean() (le profil n'existe pas encore) : le service
    de création l'appelle avant d'enregistrer, et le signal ci-dessous le rejoue à l'ajout.
    Le plafond de 3 n'est PAS vérifié ici : il dépend de l'abonnement (`profile_service`)."""
    subcategories = list(subcategories)
    if not subcategories:
        return
    if profile.type_compte not in SECTOR_TYPES:
        raise ValidationError(
            {"sous_categories": "Les prestataires et les structures n'ont pas de sous-catégories."}
        )
    if profile.secteur_id is None:
        raise ValidationError({"sous_categories": "Choisissez d'abord un secteur."})
    if any(sub.sector_id != profile.secteur_id for sub in subcategories):
        raise ValidationError(
            {"sous_categories": "Chaque sous-catégorie doit appartenir au secteur du compte."}
        )


@receiver(m2m_changed, sender=BusinessProfile.sous_categories.through)
def _check_subcategories_on_add(sender, instance, action, reverse, pk_set, **kwargs):
    if action != "pre_add" or not pk_set:
        return
    from apps.catalog.models import Subcategory

    if reverse:  # sous_categorie.business_profiles.add(profil, …)
        for profile in BusinessProfile.objects.filter(pk__in=pk_set):
            validate_subcategories(profile, [instance])
    else:
        validate_subcategories(instance, Subcategory.objects.filter(pk__in=pk_set))
