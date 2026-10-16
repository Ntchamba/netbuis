import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// Gabarit des écrans principaux : contenu de l'onglet + barre du bas
/// (Accueil · Carte · Forum · Profil, icône + mot, onglet actif en accent).
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.home_outlined), label: l10n.t('nav.home')),
            NavigationDestination(icon: const Icon(Icons.map_outlined), label: l10n.t('nav.map')),
            NavigationDestination(
              icon: const Icon(Icons.chat_bubble_outline),
              label: l10n.t('nav.forum'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              label: l10n.t('nav.profile'),
            ),
          ],
        ),
      ),
    );
  }
}
