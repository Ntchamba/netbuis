import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/settings_controller.dart';
import '../widgets/settings_page.dart';

/// Réglages : langue (Français / English), thème (Clair / Sombre / Automatique), puis
/// les écrans d'information. Chaque choix s'applique tout de suite et reste mémorisé.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    return SettingsPage(
      title: l10n.t('settings.title'),
      children: [
        _SectionTitle(l10n.t('settings.section.preferences')),
        _GroupTitle(l10n.t('settings.language.title')),
        SettingsCard(children: [
          ChoiceRow(
            key: const ValueKey('language-fr'),
            label: l10n.t('settings.language.fr'),
            selected: settings.language == 'fr',
            onTap: () => controller.setLanguage('fr'),
          ),
          ChoiceRow(
            key: const ValueKey('language-en'),
            label: l10n.t('settings.language.en'),
            selected: settings.language == 'en',
            onTap: () => controller.setLanguage('en'),
          ),
        ]),
        const SizedBox(height: 16),
        _GroupTitle(l10n.t('settings.theme.title')),
        SettingsCard(children: [
          ChoiceRow(
            key: const ValueKey('theme-light'),
            label: l10n.t('settings.theme.light'),
            selected: settings.themeMode == ThemeMode.light,
            onTap: () => controller.setThemeMode(ThemeMode.light),
          ),
          ChoiceRow(
            key: const ValueKey('theme-dark'),
            label: l10n.t('settings.theme.dark'),
            selected: settings.themeMode == ThemeMode.dark,
            onTap: () => controller.setThemeMode(ThemeMode.dark),
          ),
          ChoiceRow(
            key: const ValueKey('theme-system'),
            label: l10n.t('settings.theme.system'),
            hint: l10n.t('settings.theme.system.hint'),
            selected: settings.themeMode == ThemeMode.system,
            onTap: () => controller.setThemeMode(ThemeMode.system),
          ),
        ]),
        const SizedBox(height: 24),
        _SectionTitle(l10n.t('settings.section.information')),
        SettingsCard(children: [
          SettingsRow(
            key: const ValueKey('settings-about'),
            label: l10n.t('settings.about'),
            onTap: () => context.push(Routes.about),
          ),
          SettingsRow(
            key: const ValueKey('settings-legal'),
            label: l10n.t('settings.legal'),
            onTap: () => context.push(Routes.legalNotice),
          ),
          SettingsRow(
            key: const ValueKey('settings-terms'),
            label: l10n.t('settings.terms'),
            onTap: () => context.push(Routes.terms),
          ),
          SettingsRow(
            key: const ValueKey('settings-privacy'),
            label: l10n.t('settings.privacy'),
            onTap: () => context.push(Routes.privacy),
          ),
        ]),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Semantics(
          header: true,
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.of(context).textSecondary,
            ),
          ),
        ),
      );
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      );
}

/// Carte arrondie qui regroupe des lignes, séparées par un trait fin (style de la maquette Profil).
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: c.border));
      rows.add(children[i]);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: rows),
      ),
    );
  }
}

/// Ligne qui mène à un autre écran.
class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.label, required this.onTap, this.value});

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: value == null ? label : '$label : $value',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
                if (value != null)
                  Flexible(
                    child: Text(
                      value!,
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ),
                Icon(Icons.chevron_right, size: 20, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne de choix (une seule sélectionnée dans sa carte), avec coche.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: hint == null ? label : '$label, $hint',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
                      if (hint != null)
                        Text(hint!, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 22,
                  color: selected ? c.accentText : c.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
