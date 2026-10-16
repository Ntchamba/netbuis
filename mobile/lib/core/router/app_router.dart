import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/netbuis_logo.dart';
import 'routes.dart';

/// Routeur de l'application : 4 onglets, chacun garde sa propre pile.
GoRouter buildRouter() {
  GoRoute tab(String path, Widget screen) =>
      GoRoute(path: path, builder: (context, state) => screen);

  return GoRouter(
    initialLocation: Routes.home,
    routes: [
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
            routes: [tab(Routes.profile, const _TabScreen(titleKey: 'profile.title'))],
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
