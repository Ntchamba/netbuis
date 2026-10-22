import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/zones/zone.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../onboarding/application/city_controller.dart';
import '../../application/business_zone_rules.dart';
import '../../application/location_controller.dart';

/// Lieu choisi dans la fenêtre : la zone envoyée au serveur et son texte d'affichage.
class PickedLocation {
  const PickedLocation({required this.zoneId, required this.label});

  final int zoneId;
  final String label;
}

/// Ouvre le choix du lieu (aucune maquette) : la ville ou le village, puis le quartier
/// (facultatif). Mêmes règles que la création : jamais une région ni un département.
/// Renvoie `null` si la personne ferme la fenêtre.
Future<PickedLocation?> showEditLocationSheet(BuildContext context) {
  return showModalBottomSheet<PickedLocation>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => const FractionallySizedBox(heightFactor: 0.9, child: _EditLocationSheet()),
  );
}

class _EditLocationSheet extends ConsumerStatefulWidget {
  const _EditLocationSheet();

  @override
  ConsumerState<_EditLocationSheet> createState() => _EditLocationSheetState();
}

class _EditLocationSheetState extends ConsumerState<_EditLocationSheet> {
  final _search = TextEditingController();
  Zone? _city;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _done(Zone city, Zone? district) {
    Navigator.of(context).pop(PickedLocation(
      zoneId: (district ?? city).id,
      label: district == null ? city.name : '${city.name}, ${district.name}',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final city = _city;
    final title = city == null
        ? l10n.t('business.edit.location.title')
        : l10n.t('business.create.location.district.title');
    return Column(
      key: const ValueKey('edit-location-sheet'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
              IconButton(
                key: const ValueKey('edit-location-close'),
                tooltip: l10n.t('business.edit.location.close'),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Expanded(child: city == null ? _cities(l10n, c) : _districts(l10n, c, city)),
      ],
    );
  }

  Widget _message(String text, {VoidCallback? onRetry, bool isError = false}) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(text,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isError ? Theme.of(context).colorScheme.error : c.textSecondary)),
          ),
          if (onRetry != null)
            TextButton(
              key: const ValueKey('edit-location-retry'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onRetry,
              child: Text(l10n.t('profile.retry')),
            ),
        ],
      ),
    );
  }

  Widget _loading(String label) => Semantics(
        label: label,
        liveRegion: true,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      );

  Widget _cities(L10n l10n, AppColors c) {
    final cities = ref.watch(citiesProvider);
    return cities.when(
      loading: () => _loading(l10n.t('city.loading')),
      error: (e, _) => _message(l10n.t('business.status.error.network'),
          isError: true, onRetry: () => ref.invalidate(citiesProvider)),
      data: (list) {
        final shown = filterZonesByName(list, _search.text);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                key: const ValueKey('edit-location-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: l10n.t('business.create.location.search'),
                  prefixIcon: Icon(Icons.search, color: c.textSecondary),
                ),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? _message(l10n.t('business.create.location.noMatch'))
                  : ListView(
                      children: [
                        for (final z in shown)
                          ListTile(
                            key: ValueKey('edit-city-${z.id}'),
                            minTileHeight: 52,
                            title: Text(z.name),
                            trailing: Icon(Icons.chevron_right, color: c.textSecondary),
                            onTap: () => setState(() => _city = z),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _districts(L10n l10n, AppColors c, Zone city) {
    final districts = ref.watch(districtsProvider(city.id));
    return districts.when(
      loading: () => _loading(l10n.t('business.create.location.district.loading')),
      error: (e, _) => _message(l10n.t('business.status.error.network'),
          isError: true, onRetry: () => ref.invalidate(districtsProvider(city.id))),
      data: (list) => ListView(
        children: [
          ListTile(
            key: const ValueKey('edit-location-change-city'),
            minTileHeight: 52,
            leading: const Icon(Icons.arrow_back),
            title: Text(l10n.t('business.edit.location.changeCity')),
            onTap: () => setState(() => _city = null),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              l10n.t('business.create.location.district.subtitle').replaceAll('{city}', city.name),
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ),
          for (final d in list)
            ListTile(
              key: ValueKey('edit-district-${d.id}'),
              minTileHeight: 52,
              title: Text(d.name),
              onTap: () => _done(city, d),
            ),
          ListTile(
            key: const ValueKey('edit-district-none'),
            minTileHeight: 52,
            title: Text(l10n.t('business.create.location.district.notFound')),
            subtitle: Text(l10n
                .t('business.create.location.district.notFoundNote')
                .replaceAll('{city}', city.name)),
            onTap: () => _done(city, null),
          ),
        ],
      ),
    );
  }
}
