// Redirections selon la connexion
import '../../features/auth/application/auth_state.dart';
import 'routes.dart';

/// Chemins ouverts sans session : lancement et Découverte.
const Set<String> _openRoutes = {Routes.splash, Routes.onboarding};

/// Chemins de la connexion.
const Set<String> _loginRoutes = {Routes.login, Routes.otp};

/// Renvoie le chemin vers lequel rediriger, ou `null` pour rester.
///
/// - Pendant un chargement (restauration de la session, envoi du code…) : aucune redirection.
/// - Connecté : les écrans de connexion mènent à l'Accueil (ou à la saisie du nom
///   juste après la création du compte).
/// - Non connecté : tout écran protégé mène à la connexion ; l'écran du code
///   n'a de sens qu'après l'envoi d'un code.
String? authRedirect(AuthState auth, String location) {
  if (auth is AuthLoading) return null;
  final path = Uri.parse(location).path;
  if (_openRoutes.contains(path)) return null;
  if (auth is AuthAuthenticated) {
    if (!_loginRoutes.contains(path)) return null;
    // Première connexion : on propose d'abord de donner son nom (une seule fois,
    // car aucun écran de connexion n'est rouvert ensuite).
    return auth.isNew ? Routes.yourName : Routes.home;
  }
  if (path == Routes.login) return null;
  if (path == Routes.otp) {
    return auth is AuthLoggedOut ? Routes.login : null;
  }
  return Routes.login;
}
