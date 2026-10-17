import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/zones/zone.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/city_controller.dart';

/// « Choisir ma ville » (aucune maquette : style repris des cartes de Profil et de Découverte).
/// Grille de cartes icône + nom, sans défilement horizontal. Affichée après la
/// Découverte tant qu'aucune ville n'est mémorisée, et depuis Profil → « Ma ville ».
class ChooseCityScreen extends ConsumerWidget {
  const ChooseCityScreen({super.key});

  Future<void> _choose(BuildContext context, WidgetRef ref, Zone city) async {
    await ref.read(selectedCityProvider.notifier).select(city);
    if (!context.mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final cities = ref.watch(citiesProvider);
    final selectedId = ref.watch(selectedCityProvider).value?.id;

    final Widget body = cities.when(
      loading: () => Semantics(
        label: l10n.t('city.loading'),
        liveRegion: true,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => _Message(
        text: _errorMessage(l10n, error),
        isError: true,
        onRetry: () => ref.invalidate(citiesProvider),
      ),
      data: (list) => list.isEmpty
          ? _Message(
              text: l10n.t('city.empty'),
              onRetry: () => ref.invalidate(citiesProvider),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                const gap = 12.0;
                final width = (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final city in list)
                      SizedBox(
                        width: width,
                        child: _CityCard(
                          city: city,
                          selected: city.id == selectedId,
                          onTap: () => _choose(context, ref, city),
                        ),
                      ),
                  ],
                );
              },
            ),
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            if (context.canPop())
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  key: const ValueKey('city-back'),
                  tooltip: l10n.t('city.back'),
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
              )
            else
              const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(
                l10n.t('city.title'),
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.3),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('city.subtitle'),
              style: TextStyle(fontSize: 14, height: 1.5, color: c.textSecondary),
            ),
            const SizedBox(height: 20),
            body,
          ],
        ),
      ),
    );
  }
}

/// Message court et traduit ; jamais le texte du serveur.
String _errorMessage(L10n l10n, Object error) {
  if (error is ApiException && error.code == ApiErrorCode.network) {
    return l10n.t('city.error.network');
  }
  return l10n.t('city.error.unknown');
}

class _CityCard extends StatelessWidget {
  const _CityCard({required this.city, required this.selected, required this.onTap});

  final Zone city;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final label = selected
        ? l10n.t('city.selected').replaceAll('{name}', city.name)
        : city.name;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppColors.accent : c.border,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('city-${city.id}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 112),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accent : c.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      selected ? Icons.check : Icons.location_city_outlined,
                      size: 24,
                      color: selected ? AppColors.onAccent : c.accentText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    city.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.onRetry, this.isError = false});

  final String text;
  final bool isError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final color = isError ? Theme.of(context).colorScheme.error : c.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(isError ? Icons.error_outline : Icons.info_outline, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey('city-retry'),
          onPressed: onRetry,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(l10n.t('city.retry')),
        ),
      ],
    );
  }
}
