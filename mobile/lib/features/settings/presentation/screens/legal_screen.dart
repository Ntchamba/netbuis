import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/listen_button.dart';
import '../widgets/settings_page.dart';

/// Les trois textes légaux (provisoires, marqués À REMPLACER tant que Jeff ne les a pas fournis).
enum LegalKind {
  notice('legal.notice'),
  terms('legal.terms'),
  privacy('legal.privacy');

  const LegalKind(this.prefix);

  /// Début des clés de texte : `<prefix>.title` et `<prefix>.body`.
  final String prefix;
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.kind});

  final LegalKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final body = l10n.t('${kind.prefix}.body');
    return SettingsPage(
      title: l10n.t('${kind.prefix}.title'),
      children: [
        Text(
          body,
          key: const ValueKey('legal-body'),
          style: TextStyle(fontSize: 14, height: 1.5, color: c.textPrimary),
        ),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: ListenButton(text: body)),
      ],
    );
  }
}
