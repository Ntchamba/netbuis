import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/me.dart';

/// Blocs « Appel gratuit du jour » et « Solde de crédits » (maquette Profil). Affichés par
/// l'écran seulement quand les crédits sont activés ; une valeur `null` du serveur masque
/// sa ligne, et sans aucune valeur le bloc entier disparaît. Le bouton d'achat de la
/// maquette n'existe pas : les paiements sont reportés.
class ProfileCreditsCard extends StatelessWidget {
  const ProfileCreditsCard({super.key, required this.me});

  final Me me;

  /// Vrai s'il y a au moins une valeur à montrer.
  static bool hasContent(Me me) => me.freeCallAvailable != null || me.creditsBalance != null;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final free = me.freeCallAvailable;
    final credits = me.creditsBalance;
    final rows = <Widget>[
      if (free != null)
        _Line(
          key: const ValueKey('profile-free-call'),
          label: l10n.t('profile.free.label'),
          value: l10n.t('profile.free.value').replaceAll('{n}', '$free'),
          valueStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      if (free != null && credits != null)
        Divider(height: 1, thickness: 1, color: c.border),
      if (credits != null)
        _Line(
          key: const ValueKey('profile-credits'),
          label: l10n.t('profile.credits.label'),
          value: l10n.t('profile.credits.value').replaceAll('{n}', '$credits'),
          valueStyle:
              TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.accentText),
        ),
    ];
    return DecoratedBox(
      key: const ValueKey('profile-credits-card'),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({super.key, required this.label, required this.value, required this.valueStyle});

  final String label;
  final String value;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      container: true,
      label: '$label : $value',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
          ),
          const SizedBox(width: 8),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}
