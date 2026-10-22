import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';

/// Deux liens discrets « Conditions d'utilisation » et « Politique de confidentialité ».
/// Réutilisable (Connexion, Aide…) ; les pages sont ouvertes sans connexion.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final style = TextButton.styleFrom(
      foregroundColor: c.textSecondary,
      minimumSize: const Size(48, 48),
      textStyle: const TextStyle(fontSize: 11.5, decoration: TextDecoration.underline),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          key: const ValueKey('legal-link-terms'),
          style: style,
          onPressed: () => context.push(Routes.terms),
          child: Text(l10n.t('settings.terms')),
        ),
        TextButton(
          key: const ValueKey('legal-link-privacy'),
          style: style,
          onPressed: () => context.push(Routes.privacy),
          child: Text(l10n.t('settings.privacy')),
        ),
      ],
    );
  }
}
