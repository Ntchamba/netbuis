import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/screens/account_screen.dart';
import '../../features/account/presentation/screens/edit_profile_screen.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/business/presentation/screens/business_info_screen.dart';
import '../../features/business/presentation/screens/legal_form_screen.dart';
import '../../features/onboarding/presentation/screens/choose_city_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../l10n/l10n.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/netbuis_logo.dart';
import 'guards.dart';
import 'routes.dart';

/// Routeur de l'application : lancement, Découverte, connexion (numéro puis code),
/// puis 4 onglets, chacun garde sa propre pile. [readAuth] donne l'état de connexion
/// et [refreshListenable] relance les redirections quand il change.
GoRouter buildRouter({
  String initialLocation = Routes.splash,
  required AuthState Function() readAuth,
  Listenable? refreshListenable,
}) {
  GoRoute tab(String path, Widget screen) =>
      GoRoute(path: path, builder: (context, state) => screen);

  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: (context, state) => authRedirect(readAuth(), state.uri.toString()),
    routes: [
      GoRoute(path: Routes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: Routes.onboarding, builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: Routes.chooseCity, builder: (context, state) => const ChooseCityScreen()),
      GoRoute(path: Routes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: Routes.otp, builder: (context, state) => const OtpScreen()),
      GoRoute(
        path: Routes.yourName,
        builder: (context, state) => const EditProfileScreen(),
      ),
      // Création du compte business : une route par étape, les écrans de T031 à T035
      // s'ajoutent ici (et passent leur `BusinessStep` à `built: true`).
      GoRoute(
        path: Routes.createBusiness,
        builder: (context, state) => const BusinessInfoScreen(),
      ),
      GoRoute(
        path: Routes.createBusinessLegalForm,
        builder: (context, state) => const LegalFormScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [tab(Routes.home, const _TabScreen())]),
          StatefulShellBranch(routes: [tab(Routes.map, const _TabScreen(titleKey: 'map.title'))]),
          StatefulShellBranch(
            routes: [tab(Routes.forum, const _TabScreen(titleKey: 'forum.title'))],
          ),
          StatefulShellBranch(
            routes: [tab(Routes.profile, const AccountScreen())],
          ),
        ],
      ),
    ],
  );
}

/// Écran provisoire d'un onglet : seulement l'en-tête de la maquette
/// (logo pour Accueil, titre pour les autres). Le contenu arrive avec les tâches des onglets.
class _TabScreen extends StatelessWidget {
  const _TabScreen({this.titleKey});

  final String? titleKey;

  @override
  Widget build(BuildContext context) {
    final key = titleKey;
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: key == null
              ? const NetBuisLogo()
              : Text(L10n.of(context).t(key), style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
    );
  }
}
