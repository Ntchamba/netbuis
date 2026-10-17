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
/// - Connecté : les écrans de connexion mènent à l'Accueil.
/// - Non connecté : tout écran protégé mène à la connexion ; l'écran du code
///   n'a de sens qu'après l'envoi d'un code.
String? authRedirect(AuthState auth, String location) {
  if (auth is AuthLoading) return null;
  final path = Uri.parse(location).path;
  if (_openRoutes.contains(path)) return null;
  if (auth is AuthAuthenticated) {
    return _loginRoutes.contains(path) ? Routes.home : null;
  }
  if (path == Routes.login) return null;
  if (path == Routes.otp) {
    return auth is AuthLoggedOut ? Routes.login : null;
  }
  return Routes.login;
}
