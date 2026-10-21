// Feuille « Tous les secteurs » : grille des secteurs (icône + mot)
import 'package:flutter/material.dart';

import '../../../../core/data/referentials/referential_models.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';

/// Ouvre la grille ; renvoie le code du secteur choisi (null si la feuille est fermée sans choix).
Future<String?> showSectorsSheet(
  BuildContext context, {
  required List<Sector> sectors,
  required String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SectorsGrid(sectors: sectors, selected: selected),
  );
}

class _SectorsGrid extends StatelessWidget {
  const _SectorsGrid({required this.sectors, required this.selected});

  final List<Sector> sectors;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('home.sectors.title'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            Flexible(
              child: GridView.count(
                key: const Key('sectors-grid'),
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
                children: [
                  for (final s in sectors)
                    Semantics(
                      button: true,
                      selected: s.code == selected,
                      label: s.name,
                      excludeSemantics: true,
                      child: Material(
                        color: s.code == selected ? AppColors.accent : c.card,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.of(context).pop(s.code),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: s.code == selected ? AppColors.accent : c.border),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                s.icon.isEmpty
                                    ? Icon(Icons.category_outlined,
                                        size: 26,
                                        color: s.code == selected
                                            ? AppColors.onAccent
                                            : c.textPrimary)
                                    : Text(s.icon, style: const TextStyle(fontSize: 26, height: 1.1)),
                                const SizedBox(height: 6),
                                Text(
                                  s.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: s.code == selected
                                        ? AppColors.onAccent
                                        : c.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
