import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/zones/zone.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../onboarding/application/city_controller.dart';
import '../../../onboarding/presentation/screens/choose_city_screen.dart'
    show CityCard, CityMessage, cityErrorMessage;
import '../../application/business_draft_controller.dart';
import '../../application/business_zone_rules.dart';
import '../widgets/location_scaffold.dart';

/// Premier temps du choix du lieu (aucune maquette) : la ville ou le village. Liste des
/// zones `ville_village` (cartes de T022), recherche par nom sans tenir compte des
/// majuscules ni des accents. Un choix ouvre le second temps (quartier) ; la région ou le
/// département ne sont jamais proposés, et le brouillon les refuse de toute façon.
class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  final _search = TextEditingController();
  bool _levelRefused = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _choose(Zone city) async {
    try {
      ref.read(businessDraftProvider.notifier).setCity(city);
    } on InvalidBusinessZoneException {
      setState(() => _levelRefused = true);
      return;
    }
    if (_levelRefused) setState(() => _levelRefused = false);
    // Le second temps répond « terminé » quand le lieu est complet (quartier choisi,
    // « Je ne trouve pas mon quartier », ou ville sans quartier) : on revient alors aux
    // Informations. Un simple retour laisse l'écran ouvert, la ville est déjà gardée.
    final done = await context.push<bool>(Routes.createBusinessDistrict);
    if (done == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final cities = ref.watch(citiesProvider);
    final selectedId = ref.watch(businessDraftProvider.select((d) => d.ville?.id));

    final Widget body = cities.when(
      loading: () => Semantics(
        label: l10n.t('city.loading'),
        liveRegion: true,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => CityMessage(
        text: cityErrorMessage(l10n, error),
        isError: true,
        onRetry: () => ref.invalidate(citiesProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return CityMessage(
            text: l10n.t('city.empty'),
            onRetry: () => ref.invalidate(citiesProvider),
          );
        }
        final shown = filterZonesByName(list, _search.text);
        if (shown.isEmpty) {
          return Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.search_off, size: 18, color: c.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.t('business.create.location.noMatch'),
                      key: const ValueKey('location-no-match'),
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: c.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final width = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final city in shown)
                  SizedBox(
                    width: width,
                    child: CityCard(
                      city: city,
                      selected: city.id == selectedId,
                      selectedLabel: l10n.t('business.create.location.citySelected'),
                      onTap: () => _choose(city),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );

    final error = Theme.of(context).colorScheme.error;
    return LocationScaffold(
      title: l10n.t('business.create.location.title'),
      subtitle: l10n.t('business.create.location.subtitle'),
      children: [
        TextField(
          key: const ValueKey('location-search'),
          controller: _search,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.search,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: l10n.t('business.create.location.search'),
            hintStyle: TextStyle(fontSize: 13.5, fontStyle: FontStyle.italic, color: c.textSecondary),
            prefixIcon: Icon(Icons.search, color: c.textSecondary),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    key: const ValueKey('location-search-clear'),
                    tooltip: l10n.t('business.create.location.searchClear'),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(_search.clear),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        if (_levelRefused) ...[
          Semantics(
            liveRegion: true,
            child: Row(
              key: const ValueKey('location-level-error'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.t('business.create.error.locationLevel'),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: error),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        body,
      ],
    );
  }
}
