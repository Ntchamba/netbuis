import '../../../core/router/routes.dart';
import '../data/models/business_draft.dart';

/// Les écrans possibles du parcours de création (maquettes CreationBusiness-*).
/// Le choix précis du lieu (T034) n'est pas une étape : on l'ouvre depuis le champ
/// « Ville / Quartier » de l'écran Informations, comme dans la maquette.
enum BusinessStep {
  /// Informations de base (tous les types).
  info(Routes.createBusiness, built: true),

  /// Forme juridique + RCCM (Entreprise seulement).
  legalForm(Routes.createBusinessLegalForm, built: true),

  /// Secteur d'activité (Commerce, Entreprise, Particulier) : T031.
  sector(Routes.createBusinessSector, built: true),

  /// Détails du secteur (Commerce, Entreprise, Particulier) : T031.
  details(Routes.createBusinessDetails, built: true),

  /// Catégorie de service + CNI + diplôme (Prestataire) : T032.
  serviceCategory(Routes.createBusinessServiceCategory, built: true),

  /// Type d'établissement (Structure) : T033.
  structureType(Routes.createBusinessStructureType, built: true),

  /// Détails de l'établissement (Structure) : T033.
  structureDetails(Routes.createBusinessStructureDetails, built: true),

  /// Récapitulatif et envoi (tous les types) : T035.
  recap(Routes.createBusinessRecap);

  const BusinessStep(this.path, {this.built = false});

  /// Chemin de l'écran dans le routeur.
  final String path;

  /// Vrai quand l'écran existe et est enregistré dans le routeur. **Chaque tâche qui
  /// ajoute un écran (T031 à T035) passe ici son étape à `built: true`.**
  final bool built;
}

/// Suite ordonnée des étapes de chaque type de compte, avec le numéro « Étape X sur Y ».
/// Les totaux sont ceux des maquettes : 4 pour Commerce, Particulier et Structure ;
/// 5 pour Entreprise (forme juridique en plus) ; 3 pour Prestataire.
class BusinessCreationFlow {
  const BusinessCreationFlow._();

  static List<BusinessStep> stepsFor(BusinessAccountType type) {
    switch (type) {
      case BusinessAccountType.boutique:
      case BusinessAccountType.particulierVendeur:
        return const [
          BusinessStep.info,
          BusinessStep.sector,
          BusinessStep.details,
          BusinessStep.recap,
        ];
      case BusinessAccountType.entreprise:
        return const [
          BusinessStep.info,
          BusinessStep.legalForm,
          BusinessStep.sector,
          BusinessStep.details,
          BusinessStep.recap,
        ];
      case BusinessAccountType.prestataireService:
        return const [BusinessStep.info, BusinessStep.serviceCategory, BusinessStep.recap];
      case BusinessAccountType.structure:
        return const [
          BusinessStep.info,
          BusinessStep.structureType,
          BusinessStep.structureDetails,
          BusinessStep.recap,
        ];
    }
  }

  /// Nombre d'étapes du parcours (le « Y » de « Étape X sur Y »).
  static int total(BusinessAccountType type) => stepsFor(type).length;

  /// Numéro de l'étape à partir de 1 (le « X »), ou 0 si [step] n'existe pas pour ce type.
  static int position(BusinessAccountType type, BusinessStep step) =>
      stepsFor(type).indexOf(step) + 1;

  /// Étape qui suit [step], ou null si [step] est la dernière (ou absente du parcours).
  static BusinessStep? next(BusinessAccountType type, BusinessStep step) {
    final steps = stepsFor(type);
    final i = steps.indexOf(step);
    return i < 0 || i + 1 >= steps.length ? null : steps[i + 1];
  }

  /// Étape qui précède [step], ou null pour la première.
  static BusinessStep? previous(BusinessAccountType type, BusinessStep step) {
    final steps = stepsFor(type);
    final i = steps.indexOf(step);
    return i <= 0 ? null : steps[i - 1];
  }

  /// Chemin de l'écran suivant, ou **null s'il n'est pas encore disponible** (dernière
  /// étape, ou écran pas encore construit) : l'écran appelant montre alors
  /// « Cette étape arrive bientôt ».
  static String? nextRoute(BusinessAccountType type, BusinessStep step) {
    final n = next(type, step);
    return n != null && n.built ? n.path : null;
  }
}
