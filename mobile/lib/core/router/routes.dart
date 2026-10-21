/// Chemins des écrans.
class Routes {
  const Routes._();

  static const splash = '/splash';
  static const onboarding = '/onboarding';
  /// Choix de la ville (après la Découverte, ou depuis Profil).
  static const chooseCity = '/choose-city';
  static const login = '/login';
  static const otp = '/otp';
  /// Saisie du nom, une fois, après la première connexion.
  static const yourName = '/your-name';
  static const home = '/home';
  static const map = '/map';
  /// Recherche écrite (T045), ouverte depuis l'Accueil.
  static const search = '/search';
  /// Fiche publique d'un commerce (T047) ; modèle de chemin et chemin d'un commerce.
  static const businessDetail = '/business/:id';
  static String businessDetailPath(int id) => '/business/$id';
  static const forum = '/forum';
  static const profile = '/profile';

  /// Création du compte business : un écran par étape (protégés par la garde de connexion).
  /// Les écrans des étapes suivantes sont ajoutés par T031 à T035.
  static const createBusiness = '/create-business';
  static const createBusinessLegalForm = '/create-business/legal-form';
  static const createBusinessSector = '/create-business/sector';
  static const createBusinessDetails = '/create-business/details';
  static const createBusinessServiceCategory = '/create-business/service-category';
  static const createBusinessStructureType = '/create-business/structure-type';
  static const createBusinessStructureDetails = '/create-business/structure-details';
  static const createBusinessRecap = '/create-business/recap';

  /// « Demande envoyée » : écran final, ouvert après le succès de l'envoi (sans brouillon).
  static const createBusinessSent = '/create-business/sent';

  /// Choix précis du lieu (ville/village, puis quartier), ouvert depuis le champ
  /// « Ville / Quartier » de l'écran Informations (T034). Ce ne sont pas des étapes.
  static const createBusinessLocation = '/create-business/location';
  static const createBusinessDistrict = '/create-business/location/district';
}
