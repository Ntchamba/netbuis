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
  /// Quartier ouvert depuis l'onglet Carte (T061 : point d'entrée, T062 : le détail).
  static const mapArea = '/map/area/:id';
  static String mapAreaPath(int id) => '/map/area/$id';
  /// Recherche écrite (T045), ouverte depuis l'Accueil.
  static const search = '/search';
  /// Fiche publique d'un commerce (T047) ; modèle de chemin et chemin d'un commerce.
  static const businessDetail = '/business/:id';
  static String businessDetailPath(int id) => '/business/$id';
  static const forum = '/forum';
  /// Page d'une publication du Forum (T092).
  static const forumPost = '/forum/post/:id';
  static String forumPostPath(int id) => '/forum/post/$id';
  /// Publier (T091) et Mes publications (T091), ouverts depuis Profil.
  static const publish = '/publish';
  static const myPosts = '/my-posts';
  static const profile = '/profile';
  /// Réglages (langue, thème) et pages d'information (T100).
  static const settings = '/settings';
  static const about = '/about';
  static const legalNotice = '/legal';
  static const terms = '/terms';
  static const privacy = '/privacy';
  /// Pages lisibles sans être connecté (liées depuis l'écran de Connexion).
  static const openLegalPaths = {legalNotice, terms, privacy};
  /// Historique de mes appels (T053), ouvert depuis Profil.
  static const callHistory = '/history';

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
