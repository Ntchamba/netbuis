import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';

/// « X/3 inclus sans abonnement » (ou « Illimité · abonné ✓ » sans plafond). Partagé par
/// les sous-catégories (T031), les rayons et les spécialités (T033).
class CapCounter extends StatelessWidget {
  const CapCounter({
    super.key,
    required this.count,
    required this.limit,
    required this.atCap,
  });

  final int count;
  final int? limit;
  final bool atCap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final max = '${limit ?? 0}';
    final label = limit == null
        ? l10n.t('business.create.details.counterUnlimited')
        : l10n
            .t('business.create.details.counter')
            .replaceAll('{n}', '$count')
            .replaceAll('{max}', max);
    final spoken = limit == null
        ? label
        : l10n
            .t('business.create.details.counterSemantics')
            .replaceAll('{n}', '$count')
            .replaceAll('{max}', max);
    return Semantics(
      liveRegion: true,
      label: spoken,
      excludeSemantics: true,
      child: Text(
        label,
        key: const ValueKey('business-subcategory-counter'),
        textAlign: TextAlign.end,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: limit == null || atCap ? c.accentText : c.textSecondary,
        ),
      ),
    );
  }
}

/// Puce de choix (maquettes CreationBusiness-Details et -Structure-Details) : en pastille
/// (`tile` faux) ou en case arrondie centrée (`tile` vrai, grille à deux colonnes). Cible
/// d'au moins 48 dp. [locked] : plafond atteint (puce grisée avec 🔒, la 4e n'est pas ajoutée).
/// [exclusive] : un seul choix possible dans le groupe (cuisine, standing).
class ChoiceChipButton extends StatelessWidget {
  const ChoiceChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.selectedText,
    required this.onTap,
    this.locked = false,
    this.lockedText = '',
    this.tile = false,
    this.exclusive = false,
    this.tapKey,
  });

  final String label;
  final bool selected;
  final bool locked;

  /// Phrase lue quand la puce est choisie, avec `{label}` (« Restaurant, choisi »).
  final String selectedText;

  /// Phrase lue quand la puce est verrouillée, avec `{label}`.
  final String lockedText;
  final bool tile;
  final bool exclusive;
  final VoidCallback onTap;

  /// Clé posée sur la zone cliquable (tests).
  final Key? tapKey;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final spoken = selected
        ? selectedText.replaceAll('{label}', label)
        : (locked ? lockedText.replaceAll('{label}', label) : label);
    final radius = BorderRadius.circular(tile ? 12 : 24);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : c.card,
        borderRadius: tile ? radius : BorderRadius.circular(999),
        border: Border.all(color: selected ? AppColors.accent : c.border, width: 1.5),
      ),
      child: Padding(
        padding: tile
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text(
          locked ? '🔒 $label' : label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.onAccent : c.textPrimary,
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: exclusive,
      label: spoken,
      onTap: onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: locked ? 0.5 : 1,
        child: InkWell(
          key: tapKey,
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: tile
                ? Center(child: box)
                : Center(widthFactor: 1, child: box),
          ),
        ),
      ),
    );
  }
}

/// Encart « Limite atteinte » : l'abonnement n'est pas encore possible, le bouton est
/// donc désactivé et porte la mention « bientôt » ; « Plus tard » ferme l'encart.
/// Les textes viennent de [titleKey] et [bodyKey] (avec `{max}`).
class LimitUpsell extends StatelessWidget {
  const LimitUpsell({
    super.key,
    required this.limit,
    required this.onLater,
    this.titleKey = 'business.create.details.upsell.title',
    this.bodyKey = 'business.create.details.upsell.body',
  });

  final int? limit;
  final VoidCallback onLater;
  final String titleKey;
  final String bodyKey;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final max = '${limit ?? 0}';
    final subscribe = l10n.t('business.create.details.upsell.subscribe');
    final soon = l10n.t('business.create.details.upsell.soon');
    return DecoratedBox(
      key: const ValueKey('business-upsell'),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF241D10) : const Color(0xFFFFF6E8),
        border: Border.all(color: AppColors.accent),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.t(titleKey).replaceAll('{max}', max),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t(bodyKey).replaceAll('{max}', max),
              style: TextStyle(fontSize: 12, height: 1.45, color: c.textSecondary),
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
                child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    enabled: false,
                    label: '$subscribe, $soon',
                    excludeSemantics: true,
                    child: FilledButton(
                      key: const ValueKey('business-upsell-subscribe'),
                      onPressed: null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            subscribe,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            soon,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: const ValueKey('business-upsell-later'),
                  onPressed: onLater,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    foregroundColor: c.textSecondary,
                    side: BorderSide(color: c.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    l10n.t('business.create.details.upsell.later'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            )),
          ],
        ),
      ),
    );
  }
}
