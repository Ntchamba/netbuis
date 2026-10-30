// Feuille de filtres : zone et secteur
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../home/application/home_sectors.dart';
import '../../../home/presentation/widgets/category_chips.dart' show SectorChip;
import '../../application/search_controller.dart';
import 'zone_picker.dart';

Future<void> showFiltersSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const FiltersSheet(),
  );
}

/// Chaque choix relance la recherche tout de suite ; « Voir les résultats » ferme la feuille.
class FiltersSheet extends ConsumerWidget {
  const FiltersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final query = ref.watch(searchControllerProvider.select((s) => s.query));
    final notifier = ref.read(searchControllerProvider.notifier);
    final sectors = ref.watch(homeSectorsProvider);
    final title = Theme.of(context).textTheme.titleMedium;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('search.filters.title'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                key: const Key('filters-sheet'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.t('search.filters.zone'), style: title),
                    const SizedBox(height: 8),
                    ZonePicker(selected: query.zone, onSelect: notifier.setZone),
                    const SizedBox(height: 20),
                    Text(l10n.t('search.filters.sector'), style: title),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SectorChip(
                          key: const Key('sector-all'),
                          label: l10n.t('search.filters.sectorAll'),
                          icon: l10n.t('home.chip.allIcon'),
                          selected: query.sector == null,
                          onTap: () => notifier.setSector(null),
                        ),
                        ...sectors.when(
                          data: (list) => [
                            for (final s in list)
                              SectorChip(
                                key: Key('sector-${s.code}'),
                                label: s.name,
                                icon: s.icon,
                                selected: query.sector == s.code,
                                onTap: () => notifier.setSector(s.code),
                              ),
                          ],
                          loading: () => const <Widget>[],
                          error: (_, __) => [Text(l10n.t('search.filters.sectorError'))],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                key: const Key('filters-apply'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.search, size: 20),
                label: Text(l10n.t('search.filters.apply')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
