import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/screens/account_screen.dart';
import '../../features/account/presentation/screens/edit_profile_screen.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/business/presentation/screens/business_detail_screen.dart';
import '../../features/business/presentation/screens/business_edit_screen.dart';
import '../../features/business/presentation/screens/business_info_screen.dart';
import '../../features/business/presentation/screens/details_screen.dart';
import '../../features/business/presentation/screens/district_screen.dart';
import '../../features/business/presentation/screens/legal_form_screen.dart';
import '../../features/business/presentation/screens/location_screen.dart';
import '../../features/business/presentation/screens/recap_screen.dart';
import '../../features/business/presentation/screens/sector_screen.dart';
import '../../features/business/presentation/screens/sent_screen.dart';
import '../../features/business/presentation/screens/service_category_screen.dart';
import '../../features/business/presentation/screens/structure_details_screen.dart';
import '../../features/business/presentation/screens/structure_type_screen.dart';
import '../../features/call/presentation/screens/call_history_screen.dart';
import '../../features/forum/presentation/screens/forum_screen.dart';
import '../../features/forum/presentation/screens/my_posts_screen.dart';
import '../../features/forum/presentation/screens/post_screen.dart';
import '../../features/forum/presentation/screens/publish_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/maps/presentation/screens/area_screen.dart';
import '../../features/maps/presentation/screens/map_screen.dart';
import '../../features/onboarding/presentation/screens/choose_city_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/about_screen.dart';
import '../../features/settings/presentation/screens/help_screen.dart';
import '../../features/settings/presentation/screens/legal_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
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
    redirect: (context, state) {
      if (Routes.openLegalPaths.contains(state.uri.path)) return null;
      return authRedirect(readAuth(), state.uri.toString());
    },
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
      GoRoute(
        path: Routes.createBusinessSector,
        builder: (context, state) => const SectorScreen(),
      ),
      GoRoute(
        path: Routes.createBusinessServiceCategory,
        builder: (context, state) => const ServiceCategoryScreen(),
      ),
      GoRoute(
        path: Routes.createBusinessDetails,
        builder: (context, state) => const DetailsScreen(),
      ),
      GoRoute(
        path: Routes.createBusinessStructureType,
        builder: (context, state) => const StructureTypeScreen(),
      ),
      GoRoute(
        path: Routes.createBusinessStructureDetails,
        builder: (context, state) => const StructureDetailsScreen(),
      ),
      GoRoute(
        path: Routes.createBusinessRecap,
        builder: (context, state) => const RecapScreen(),
      ),
      GoRoute(
        path: Routes.createBusinessSent,
        builder: (context, state) => const SentScreen(),
      ),
      GoRoute(
        path: Routes.editBusiness,
        builder: (context, state) => const BusinessEditScreen(),
      ),
      GoRoute(
        path: Routes.createBusinessLocation,
        builder: (context, state) => const LocationScreen(),
      ),
      GoRoute(
        path: Routes.createBusinessDistrict,
        builder: (context, state) => const DistrictScreen(),
      ),
      GoRoute(
        path: Routes.callHistory,
        builder: (context, state) => const CallHistoryScreen(),
      ),
      GoRoute(path: Routes.settings, builder: (context, state) => const SettingsScreen()),
      GoRoute(path: Routes.about, builder: (context, state) => const AboutScreen()),
      GoRoute(
        path: Routes.legalNotice,
        builder: (context, state) => const LegalScreen(kind: LegalKind.notice),
      ),
      GoRoute(
        path: Routes.terms,
        builder: (context, state) => const LegalScreen(kind: LegalKind.terms),
      ),
      GoRoute(
        path: Routes.privacy,
        builder: (context, state) => const LegalScreen(kind: LegalKind.privacy),
      ),
      GoRoute(path: Routes.help, builder: (context, state) => const HelpScreen()),
      GoRoute(path: Routes.publish, builder: (context, state) => const PublishScreen()),
      GoRoute(path: Routes.myPosts, builder: (context, state) => const MyPostsScreen()),
      GoRoute(
        path: Routes.forumPost,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return id == null
              ? const Scaffold(body: _TabScreen(titleKey: 'forum.title'))
              : PostScreen(postId: id);
        },
      ),
      GoRoute(path: Routes.search, builder: (context, state) => const SearchScreen()),
      GoRoute(
        path: Routes.businessDetail,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return id == null
              ? const _TabScreen(titleKey: 'business.detail.notFound.title')
              : BusinessDetailScreen(businessId: id);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) =>
                    HomeScreen(onOpenSearch: () => context.push(Routes.search)),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.map,
                builder: (context, state) => const MapScreen(),
                routes: [
                  // Détail d'un quartier (T062) ; `extra` : AreaArgs (fil d'Ariane).
                  GoRoute(
                    path: 'area/:id',
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      final extra = state.extra;
                      return id == null
                          ? const Scaffold(body: _TabScreen(titleKey: 'map.area.title'))
                          : AreaScreen(areaId: id, args: extra is AreaArgs ? extra : null);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [tab(Routes.forum, const ForumScreen())],
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
