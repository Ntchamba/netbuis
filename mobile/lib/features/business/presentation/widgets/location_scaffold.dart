import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';

/// Gabarit des deux écrans du choix du lieu (T034, aucune maquette) : bouton retour rond
/// comme dans le parcours de création, titre, sous-titre, puis le contenu qui défile
/// verticalement. Pas de bouton « Continuer » : un choix suffit.
class LocationScaffold extends StatelessWidget {
  const LocationScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    void back() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.createBusiness);
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: l10n.t('business.create.back'),
                    excludeSemantics: true,
                    onTap: back,
                    child: InkResponse(
                      key: const ValueKey('location-back'),
                      onTap: back,
                      radius: 24,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.card,
                              border: Border.all(color: c.border),
                            ),
                            child: Icon(Icons.chevron_left, size: 22, color: c.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, height: 1.5, color: c.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ...children,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
