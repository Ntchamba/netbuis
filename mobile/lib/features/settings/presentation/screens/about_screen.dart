import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/app_info.dart';
import '../widgets/settings_page.dart';
import 'settings_screen.dart';

/// « À propos » : nom, version, courte présentation et accès aux textes légaux.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return SettingsPage(
      title: l10n.t('about.title'),
      children: [
        Text(appName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          l10n.t('about.version').replaceAll('{version}', appVersion),
          key: const ValueKey('about-version'),
          style: TextStyle(fontSize: 13, color: c.textSecondary),
        ),
        const SizedBox(height: 16),
        Text(l10n.t('about.tagline'), style: const TextStyle(fontSize: 14, height: 1.5)),
        const SizedBox(height: 8),
        Text(
          l10n.t('about.placeholder'),
          style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary),
        ),
        const SizedBox(height: 20),
        SettingsCard(children: [
          SettingsRow(
            key: const ValueKey('about-legal'),
            label: l10n.t('settings.legal'),
            onTap: () => context.push(Routes.legalNotice),
          ),
          SettingsRow(
            key: const ValueKey('about-terms'),
            label: l10n.t('settings.terms'),
            onTap: () => context.push(Routes.terms),
          ),
          SettingsRow(
            key: const ValueKey('about-privacy'),
            label: l10n.t('settings.privacy'),
            onTap: () => context.push(Routes.privacy),
          ),
        ]),
      ],
    );
  }
}
