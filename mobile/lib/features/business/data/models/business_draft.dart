// Brouillon de la demande de compte business (corps de POST /api/business/)
import '../../../../core/data/referentials/referential_models.dart';

/// Longueurs maximales du serveur (backend/apps/business/models/profile.py, openapi.yaml).
const int kBusinessNameMax = 150;
const int kBusinessRepereMax = 150;
const int kBusinessRepresentantMax = 150;
const int kBusinessRccmMax = 50;

/// `secteur_libre` : 100 caractères au plus (profile.py).
const int kBusinessSecteurLibreMax = 100;

/// `description_activite` : 500 caractères au plus (profile.py).
const int kBusinessDescriptionActiviteMax = 500;

/// Code du secteur « Autre » (celui qui ouvre le nom libre).
const String kOtherSectorCode = 'autre';

/// `categorie_service_libre` : 100 caractères au plus (profile.py).
const int kBusinessCategorieServiceLibreMax = 100;

/// Code de la catégorie de service « Autre » (celle qui ouvre le texte libre).
const String kOtherServiceCategoryCode = 'autre';

/// `structure_type_libre` : 100 caractères au plus (profile.py).
const int kBusinessStructureTypeLibreMax = 100;

/// `description` du profil : 1000 caractères au plus (profile.py).
const int kBusinessDescriptionMax = 1000;

/// `horaires` (restaurant) : 200 caractères au plus (profile.py).
const int kBusinessHorairesMax = 200;

/// `numero_agrement` (centre de santé) : 50 caractères au plus (profile.py).
const int kBusinessNumeroAgrementMax = 50;

/// Nombre de chambres : le serveur refuse moins de 1 (profile.py) et n'a pour plafond que
/// celui d'un entier ; l'application borne la saisie à 4 chiffres (1 à 9999).
const int kBusinessChambresMin = 1;
const int kBusinessChambresMax = 9999;

/// Code du type d'établissement « Autre » (celui qui ouvre le texte libre).
const String kOtherStructureTypeCode = 'autre';

/// Codes des types d'établissement du serveur (GET /api/referentials/structure-types/).
const String kStructureSupermarche = 'supermarche';
const String kStructureRestaurant = 'restaurant';
const String kStructureHotel = 'hotel';
const String kStructureSante = 'sante';

/// Nombre de sous-catégories incluses sans abonnement (décision D-12). Aucune route ne
/// publie encore cette valeur : c'est une constante de l'application. Le serveur reste
/// l'autorité (erreur `SUBSCRIPTION_REQUIRED` à l'envoi, T035).
const int freeSubcategoryLimit = 3;

/// Type de compte (`type_compte`). [value] est le code échangé avec le serveur.
enum BusinessAccountType {
  boutique('boutique'),
  entreprise('entreprise'),
  particulierVendeur('particulier_vendeur'),
  prestataireService('prestataire_service'),
  structure('structure');

  const BusinessAccountType(this.value);

  final String value;

  /// Commerce, Entreprise et Particulier : secteur, sous-catégories, description d'activité.
  bool get hasSector => this == boutique || this == entreprise || this == particulierVendeur;
}

/// Forme juridique d'une entreprise (`forme_juridique`), dans l'ordre de la maquette.
enum LegalForm {
  individuelle('individuelle'),
  sarl('sarl'),
  sarlu('sarlu'),
  sa('sa'),
  gicCooperative('gic_cooperative'),
  association('association'),
  etablissementPublic('etablissement_public'),
  autre('autre');

  const LegalForm(this.value);

  /// Code du serveur, envoyé tel quel.
  final String value;
}

/// Pourquoi un champ est refusé (l'écran choisit le message traduit).
enum FieldError { required, tooLong }

int _length(String s) => s.runes.length;

/// Nom affiché : obligatoire, 150 caractères au plus (espaces des bouts retirés).
FieldError? validateBusinessName(String raw) => _requiredText(raw, kBusinessNameMax);

/// Nom du représentant : obligatoire, 150 caractères au plus.
FieldError? validateRepresentantName(String raw) => _requiredText(raw, kBusinessRepresentantMax);

FieldError? _requiredText(String raw, int max) {
  final v = raw.trim();
  if (v.isEmpty) return FieldError.required;
  if (_length(v) > max) return FieldError.tooLong;
  return null;
}

const Object _keep = Object();

/// Ce que la personne a rempli pendant la création de son compte business. Immuable ;
/// vit en mémoire seulement (jamais sur le disque : il contient des photos et des noms).
///
/// Les champs portent les noms du contrat (openapi.yaml, `BusinessProfile`). Les photos sont
/// ici des **chemins de fichiers locaux** : l'envoi et la conversion en clés de stockage
/// (`photo`, `representant_photo`, `cni_photo`, `diplome_photo`) se font à l'envoi (T035).
/// Le numéro de téléphone n'est pas ici : l'écran montre seulement le numéro masqué du compte.
class BusinessDraft {
  const BusinessDraft({
    this.typeCompte = BusinessAccountType.boutique,
    this.name = '',
    this.repere = '',
    this.description = '',
    this.photoPath,
    this.representantNom = '',
    this.representantPhotoPath,
    this.zoneId,
    this.formeJuridique,
    this.rccm = '',
    this.secteurId,
    this.secteur,
    this.secteurLibre = '',
    this.sousCategorieIds = const [],
    this.descriptionActivite = '',
    this.categorieServiceId,
    this.categorieService,
    this.categorieServiceLibre = '',
    this.cniPhotoPath,
    this.diplomePhotoPath,
    this.structureTypeId,
    this.structureType,
    this.structureTypeLibre = '',
    this.rayons = const [],
    this.cuisine = '',
    this.livraison,
    this.horaires = '',
    this.standing = '',
    this.nombreChambres,
    this.equipements = const [],
    this.numeroAgrement = '',
    this.specialites = const [],
  });

  // Communs aux cinq types.
  final BusinessAccountType typeCompte;
  final String name;
  final String repere;
  final String description;
  final String? photoPath;
  final String representantNom;
  final String? representantPhotoPath;

  /// Identifiant de la ville/village ou du quartier (écran du lieu, T034).
  final int? zoneId;

  // Entreprise.
  final LegalForm? formeJuridique;
  final String rccm;

  // Commerce, Entreprise, Particulier.
  final int? secteurId;

  /// Le secteur choisi (nom, icône, sous-catégories), gardé pour l'affichage des écrans
  /// Secteur et Détails. Toujours cohérent avec [secteurId].
  final Sector? secteur;
  final String secteurLibre;
  final List<int> sousCategorieIds;
  final String descriptionActivite;

  // Prestataire de service.
  final int? categorieServiceId;

  /// La catégorie de service choisie (nom, code), gardée pour l'affichage. Toujours
  /// cohérente avec [categorieServiceId].
  final ReferentialItem? categorieService;
  final String categorieServiceLibre;

  /// Chemin **local** de la photo de la CNI (obligatoire). Gardé en mémoire seulement :
  /// jamais écrit en préférences, jamais journalisé, jamais affiché en entier au public.
  final String? cniPhotoPath;

  /// Chemin local de la photo du diplôme (facultatif).
  final String? diplomePhotoPath;

  // Structure.
  final int? structureTypeId;

  /// Le type d'établissement choisi (nom, icône, code), gardé pour l'affichage. Toujours
  /// cohérent avec [structureTypeId].
  final ReferentialItem? structureType;
  final String structureTypeLibre;
  final List<String> rayons;
  final String cuisine;
  final bool? livraison;
  final String horaires;
  final String standing;
  final int? nombreChambres;
  final List<String> equipements;
  final String numeroAgrement;
  final List<String> specialites;

  /// Copie avec changements. Pour un champ pouvant être vide (`null`), passer `null`
  /// l'efface ; ne rien passer le conserve.
  BusinessDraft copyWith({
    BusinessAccountType? typeCompte,
    String? name,
    String? repere,
    String? description,
    Object? photoPath = _keep,
    String? representantNom,
    Object? representantPhotoPath = _keep,
    Object? zoneId = _keep,
    Object? formeJuridique = _keep,
    String? rccm,
    Object? secteurId = _keep,
    Object? secteur = _keep,
    String? secteurLibre,
    List<int>? sousCategorieIds,
    String? descriptionActivite,
    Object? categorieServiceId = _keep,
    Object? categorieService = _keep,
    String? categorieServiceLibre,
    Object? cniPhotoPath = _keep,
    Object? diplomePhotoPath = _keep,
    Object? structureTypeId = _keep,
    Object? structureType = _keep,
    String? structureTypeLibre,
    List<String>? rayons,
    String? cuisine,
    Object? livraison = _keep,
    String? horaires,
    String? standing,
    Object? nombreChambres = _keep,
    List<String>? equipements,
    String? numeroAgrement,
    List<String>? specialites,
  }) {
    return BusinessDraft(
      typeCompte: typeCompte ?? this.typeCompte,
      name: name ?? this.name,
      repere: repere ?? this.repere,
      description: description ?? this.description,
      photoPath: identical(photoPath, _keep) ? this.photoPath : photoPath as String?,
      representantNom: representantNom ?? this.representantNom,
      representantPhotoPath: identical(representantPhotoPath, _keep)
          ? this.representantPhotoPath
          : representantPhotoPath as String?,
      zoneId: identical(zoneId, _keep) ? this.zoneId : zoneId as int?,
      formeJuridique: identical(formeJuridique, _keep)
          ? this.formeJuridique
          : formeJuridique as LegalForm?,
      rccm: rccm ?? this.rccm,
      secteurId: identical(secteurId, _keep) ? this.secteurId : secteurId as int?,
      secteur: identical(secteur, _keep) ? this.secteur : secteur as Sector?,
      secteurLibre: secteurLibre ?? this.secteurLibre,
      sousCategorieIds: sousCategorieIds ?? this.sousCategorieIds,
      descriptionActivite: descriptionActivite ?? this.descriptionActivite,
      categorieServiceId: identical(categorieServiceId, _keep)
          ? this.categorieServiceId
          : categorieServiceId as int?,
      categorieService: identical(categorieService, _keep)
          ? this.categorieService
          : categorieService as ReferentialItem?,
      categorieServiceLibre: categorieServiceLibre ?? this.categorieServiceLibre,
      cniPhotoPath: identical(cniPhotoPath, _keep) ? this.cniPhotoPath : cniPhotoPath as String?,
      diplomePhotoPath: identical(diplomePhotoPath, _keep)
          ? this.diplomePhotoPath
          : diplomePhotoPath as String?,
      structureTypeId: identical(structureTypeId, _keep)
          ? this.structureTypeId
          : structureTypeId as int?,
      structureType: identical(structureType, _keep)
          ? this.structureType
          : structureType as ReferentialItem?,
      structureTypeLibre: structureTypeLibre ?? this.structureTypeLibre,
      rayons: rayons ?? this.rayons,
      cuisine: cuisine ?? this.cuisine,
      livraison: identical(livraison, _keep) ? this.livraison : livraison as bool?,
      horaires: horaires ?? this.horaires,
      standing: standing ?? this.standing,
      nombreChambres:
          identical(nombreChambres, _keep) ? this.nombreChambres : nombreChambres as int?,
      equipements: equipements ?? this.equipements,
      numeroAgrement: numeroAgrement ?? this.numeroAgrement,
      specialites: specialites ?? this.specialites,
    );
  }

  /// Change le type de compte et **vide** ce qui n'a plus d'objet pour le nouveau type
  /// (le serveur refuse les champs d'un autre type). Les champs communs (nom, repère,
  /// description, photos, représentant, lieu) sont conservés ; le secteur est conservé
  /// entre Commerce, Entreprise et Particulier, qui partagent le même parcours.
  BusinessDraft withType(BusinessAccountType type) {
    if (type == typeCompte) return this;
    var d = copyWith(typeCompte: type);
    if (type != BusinessAccountType.entreprise) {
      d = d.copyWith(formeJuridique: null, rccm: '');
    }
    if (!type.hasSector) {
      d = d.copyWith(
        secteurId: null,
        secteur: null,
        secteurLibre: '',
        sousCategorieIds: const [],
        descriptionActivite: '',
      );
    }
    if (type != BusinessAccountType.prestataireService) {
      d = d.copyWith(
        categorieServiceId: null,
        categorieService: null,
        categorieServiceLibre: '',
        cniPhotoPath: null,
        diplomePhotoPath: null,
      );
    }
    if (type != BusinessAccountType.structure) {
      d = d.copyWith(
        structureTypeId: null,
        structureType: null,
        structureTypeLibre: '',
      );
      d = d._withoutStructureDetails();
    }
    return d;
  }

  /// Vide les détails propres à un type d'établissement (la description, commune, reste).
  BusinessDraft _withoutStructureDetails() => copyWith(
        rayons: const [],
        cuisine: '',
        livraison: null,
        horaires: '',
        standing: '',
        nombreChambres: null,
        equipements: const [],
        numeroAgrement: '',
        specialites: const [],
      );

  /// Choisit le type d'établissement. Un autre type **vide** le texte libre et tous les
  /// détails de l'ancien type (rayons, cuisine, standing…) ; la description, commune à tous
  /// les types, est conservée. Le même type ne change rien.
  BusinessDraft withStructureType(ReferentialItem type) {
    if (structureTypeId == type.id) return this;
    return copyWith(
      structureTypeId: type.id,
      structureType: type,
      structureTypeLibre: '',
    )._withoutStructureDetails();
  }

  /// Code du type d'établissement choisi (`supermarche`, `restaurant`, `hotel`, `sante`,
  /// `autre`), ou null.
  String? get structureCode => structureType?.code;

  /// Vrai si le type d'établissement (obligatoire) manque.
  bool get structureTypeMissing => structureTypeId == null;

  /// Vrai si le type choisi est « Autre » (texte libre à écrire).
  bool get isOtherStructureType => structureCode == kOtherStructureTypeCode;

  /// Erreur du texte libre du type « Autre » (null = valide ou sans objet).
  FieldError? get structureTypeLibreError => isOtherStructureType
      ? _requiredText(structureTypeLibre, kBusinessStructureTypeLibreMax)
      : null;

  /// Supermarché : au moins un rayon.
  bool get rayonsMissing => structureCode == kStructureSupermarche && rayons.isEmpty;

  /// Restaurant : le type de cuisine est obligatoire.
  bool get cuisineMissing => structureCode == kStructureRestaurant && cuisine.isEmpty;

  /// Restaurant : livraison oui ou non, obligatoire.
  bool get livraisonMissing => structureCode == kStructureRestaurant && livraison == null;

  /// Hôtel : le standing est obligatoire.
  bool get standingMissing => structureCode == kStructureHotel && standing.isEmpty;

  /// Hôtel : le nombre de chambres est facultatif ; s'il est donné, 1 à 9999.
  bool get nombreChambresInvalid =>
      structureCode == kStructureHotel &&
      nombreChambres != null &&
      (nombreChambres! < kBusinessChambresMin || nombreChambres! > kBusinessChambresMax);

  /// Centre de santé : au moins une spécialité.
  bool get specialitesMissing => structureCode == kStructureSante && specialites.isEmpty;

  /// Description libre de l'établissement : facultative, 1000 caractères au plus.
  FieldError? get descriptionError =>
      _length(description.trim()) > kBusinessDescriptionMax ? FieldError.tooLong : null;

  /// L'écran « Type d'établissement » est complet.
  bool get structureTypeStepIsValid => !structureTypeMissing;

  /// L'écran « Détails de l'établissement » est complet.
  bool get structureDetailsIsValid =>
      !structureTypeMissing &&
      structureTypeLibreError == null &&
      !rayonsMissing &&
      !cuisineMissing &&
      !livraisonMissing &&
      !standingMissing &&
      !nombreChambresInvalid &&
      !specialitesMissing &&
      descriptionError == null;

  /// Choisit le secteur. Un autre secteur **vide** ce qui appartenait à l'ancien : les
  /// sous-catégories, le nom libre et la description. Le même secteur ne change rien.
  BusinessDraft withSector(Sector sector) {
    if (secteurId == sector.id) return this;
    return copyWith(
      secteurId: sector.id,
      secteur: sector,
      secteurLibre: '',
      sousCategorieIds: const [],
      descriptionActivite: '',
    );
  }

  /// Choisit la catégorie de service (une seule). Une autre catégorie **vide** le texte
  /// libre, devenu sans objet. La même catégorie ne change rien.
  BusinessDraft withServiceCategory(ReferentialItem category) {
    if (categorieServiceId == category.id) return this;
    return copyWith(
      categorieServiceId: category.id,
      categorieService: category,
      categorieServiceLibre: '',
    );
  }

  /// Vrai si la catégorie de service choisie est « Autre » (texte libre à écrire).
  bool get isOtherServiceCategory => categorieService?.code == kOtherServiceCategoryCode;

  /// Vrai si la catégorie de service (obligatoire) manque.
  bool get serviceCategoryMissing => categorieServiceId == null;

  /// Erreur du texte libre de la catégorie « Autre » (null = valide ou sans objet).
  FieldError? get categorieServiceLibreError => isOtherServiceCategory
      ? _requiredText(categorieServiceLibre, kBusinessCategorieServiceLibreMax)
      : null;

  /// Vrai si la photo de la CNI (obligatoire) manque.
  bool get cniPhotoMissing => cniPhotoPath == null;

  /// L'écran « Catégorie & vérification » est complet : le diplôme est facultatif.
  bool get serviceStepIsValid =>
      !serviceCategoryMissing && categorieServiceLibreError == null && !cniPhotoMissing;

  /// Vrai si le secteur choisi est « Autre » (nom libre à écrire).
  bool get isOtherSector => secteur?.code == kOtherSectorCode;

  /// Vrai si le secteur (obligatoire) manque.
  bool get sectorMissing => secteurId == null;

  /// Erreur du nom libre du secteur « Autre » (null = valide ou sans objet).
  FieldError? get secteurLibreError =>
      isOtherSector ? _requiredText(secteurLibre, kBusinessSecteurLibreMax) : null;

  /// Erreur de la description : obligatoire pour « Autre », facultative sinon.
  FieldError? get descriptionActiviteError {
    final v = descriptionActivite.trim();
    if (v.isEmpty) return isOtherSector ? FieldError.required : null;
    return _length(v) > kBusinessDescriptionActiviteMax ? FieldError.tooLong : null;
  }

  /// L'écran Détails est complet.
  bool get detailsIsValid =>
      !sectorMissing && secteurLibreError == null && descriptionActiviteError == null;

  /// Erreur du nom affiché (null = valide).
  FieldError? get nameError => validateBusinessName(name);

  /// Erreur du nom du représentant (null = valide).
  FieldError? get representantNomError => validateRepresentantName(representantNom);

  /// Vrai si la photo du représentant (obligatoire) manque.
  bool get representantPhotoMissing => representantPhotoPath == null;

  /// Les champs obligatoires de l'écran Informations sont remplis et valides.
  bool get infoIsValid =>
      nameError == null && representantNomError == null && !representantPhotoMissing;
}
