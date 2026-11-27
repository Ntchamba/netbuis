// Choix de la zone dans la feuille de filtres : toutes les zones, la ville, ses quartiers
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/zones/zone.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../home/presentation/widgets/category_chips.dart' show SectorChip;
import '../../../onboarding/application/city_controller.dart';

/// Quartiers (ou zones filles) de la ville choisie. Pas de nouvel essai automatique.
final searchZonesProvider = FutureProvider.autoDispose<List<Zone>>((ref) async {
  final city = await ref.watch(selectedCityProvider.future);
  if (city == null) return const [];
  return ref.read(zoneRepositoryProvider).listZones(parent: city.id);
}, retry: (retryCount, error) => null);

class ZonePicker extends ConsumerWidget {
  const ZonePicker({super.key, required this.selected, required this.onSelect});

  /// Zone choisie ; null = toutes les zones.
  final int? selected;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final city = ref.watch(selectedCityProvider).value;
    final zones = ref.watch(searchZonesProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SectorChip(
          key: const Key('zone-all'),
          label: l10n.t('search.filters.zoneAll'),
          icon: '🌍',
          selected: selected == null,
          onTap: () => onSelect(null),
        ),
        if (city != null)
          SectorChip(
            key: Key('zone-${city.id}'),
            label: l10n.t('search.filters.zoneCity').replaceAll('{name}', city.name),
            icon: '📍',
            selected: selected == city.id,
            onTap: () => onSelect(city.id),
          ),
        ...zones.when(
          data: (list) => [
            for (final z in list)
              SectorChip(
                key: Key('zone-${z.id}'),
                label: z.name,
                icon: '',
                selected: selected == z.id,
                onTap: () => onSelect(z.id),
              ),
          ],
          loading: () => const <Widget>[],
          error: (_, __) => [Text(l10n.t('search.filters.zoneError'))],
        ),
      ],
    );
  }
}
