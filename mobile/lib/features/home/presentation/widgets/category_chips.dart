// Puces de secteurs : « Tous » puis les secteurs, qui passent à la ligne (jamais de défilement)
import 'package:flutter/material.dart';

import '../../../../core/data/referentials/referential_models.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';

/// Secteurs visibles à côté de « Tous » et de « plus » (comme la maquette : 4 puces).
const int kVisibleSectorChips = 2;

/// Secteurs montrés en puces : les premiers, sauf que le secteur choisi, s'il est plus loin,
/// prend la place du dernier pour rester visible.
List<Sector> visibleSectors(List<Sector> sectors, String? selected) {
  final shown = sectors.take(kVisibleSectorChips).toList();
  if (selected == null || shown.any((s) => s.code == selected)) return shown;
  final chosen = sectors.where((s) => s.code == selected);
  if (chosen.isEmpty || shown.isEmpty) return shown;
  shown[shown.length - 1] = chosen.first;
  return shown;
}

class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.sectors,
    required this.selected,
    required this.onSelect,
    required this.onMore,
  });

  final List<Sector> sectors;

  /// Code du secteur choisi, null = « Tous ».
  final String? selected;
  final ValueChanged<String?> onSelect;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Wrap(
      spacing: 8,
      // Puces de 48 dp de haut (cible tactile) : l'espace entre les lignes est réduit pour que
      // la zone des résultats garde sa hauteur.
      runSpacing: 4,
      children: [
        SectorChip(
          label: l10n.t('home.chip.all'),
          icon: l10n.t('home.chip.allIcon'),
          selected: selected == null,
          onTap: () => onSelect(null),
        ),
        for (final s in visibleSectors(sectors, selected))
          SectorChip(
            label: s.name,
            icon: s.icon,
            selected: selected == s.code,
            onTap: () => onSelect(s.code),
          ),
        if (sectors.length > kVisibleSectorChips)
          SectorChip(
            key: const Key('chip-more'),
            label: l10n.t('home.chip.more'),
            icon: l10n.t('home.chip.moreIcon'),
            selected: false,
            semanticLabel: l10n.t('home.chip.moreLabel'),
            onTap: onMore,
          ),
      ],
    );
  }
}

/// Une puce : icône (pictogramme du serveur, sinon une icône neutre) + mot.
class SectorChip extends StatelessWidget {
  const SectorChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = selected ? AppColors.onAccent : c.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.accent : c.card,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.accent : c.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon.isEmpty)
                    Icon(Icons.category_outlined, size: 16, color: fg)
                  else
                    Text(icon, style: const TextStyle(fontSize: 14, height: 1)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
