// Écran Carte « Explorer » (maquette Carte) : villes actives sur un cadre schématique ou en liste,
// puis quartiers d'une ville. Aucune carte tierce ; positions indicatives (pas de GPS en v1).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../search/application/offline_controller.dart';
import '../../application/map_controller.dart';
import '../../application/map_layout.dart';
import '../../data/models/map_models.dart';
import '../widgets/map_canvas.dart';
import 'area_screen.dart';

String _fill(String text, Map<String, Object> values) {
  var out = text;
  values.forEach((k, v) => out = out.replaceAll('{$k}', '$v'));
  return out;
}

String _plural(L10n l10n, String base, int n) =>
    _fill(l10n.t(n == 1 ? '$base.one' : '$base.other'), {'count': n});

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.onOpenArea});

  /// Ouvre le détail d'un quartier (T062). Par défaut : route `Routes.mapArea`.
  final void Function(MapArea area)? onOpenArea;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openArea(MapArea area) {
    final open = widget.onOpenArea;
    if (open != null) {
      open(area);
    } else {
      context.push(
        Routes.mapAreaPath(area.id),
        extra: AreaArgs(
          areaName: area.name,
          cityId: ref.read(mapControllerProvider).activeCity?.id,
          cityName: ref.read(mapControllerProvider).activeCity?.name,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final state = ref.watch(mapControllerProvider);
    final notifier = ref.read(mapControllerProvider.notifier);
    ref.listen(mapControllerProvider.select((s) => s.inCity), (_, __) => _search.clear());

    final String location;
    final city = state.activeCity;
    if (city == null) {
      final n = state.cities.length;
      location = n == 1
          ? l10n.t('map.location.one')
          : _fill(l10n.t('map.location.all'), {'count': n});
    } else {
      final region = city.region?.name;
      location = region == null ? city.name : '${city.name}, $region';
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(l10n.t('map.title'),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      if (city != null)
                        IconButton(
                          key: const Key('map-back'),
                          tooltip: l10n.t('map.back'),
                          onPressed: notifier.backToCities,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            side: BorderSide(color: c.border),
                            backgroundColor: c.card,
                          ),
                          icon: const Icon(Icons.chevron_left, size: 20),
                        ),
                      if (state.status == MapStatus.ready || city != null)
                        Flexible(
                          child: Container(
                            key: const Key('map-location'),
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: c.card,
                              border: Border.all(color: c.border),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(location,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ],
                  ),
                  if (city == null) ...[
                    const SizedBox(height: 6),
                    Text(l10n.t('map.subtitle.cities'),
                        style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  ],
                  const SizedBox(height: 12),
                  _Tabs(view: state.view, onMap: notifier.showMap, onList: notifier.showList),
                ],
              ),
            ),
            if (ref.watch(offlineProvider) && (state.status == MapStatus.ready || city != null))
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(l10n.t('map.offline'),
                    key: const Key('map-offline'),
                    style: TextStyle(fontSize: 13, color: c.textSecondary)),
              ),
            Expanded(child: _body(context, state, notifier)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, MapState state, MapController notifier) {
    final l10n = L10n.of(context);
    final offline = ref.watch(offlineProvider);
    final city = state.activeCity;

    if (city == null) {
      switch (state.status) {
        case MapStatus.loading:
          return _Loading(label: l10n.t('map.loading'));
        case MapStatus.error:
          return _Message(
            key: const Key('map-error'),
            icon: offline ? Icons.cloud_off_outlined : Icons.error_outline,
            title: l10n.t(offline ? 'map.offline' : 'map.error'),
            action: _RetryButton(onPressed: notifier.retry),
          );
        case MapStatus.empty:
          return _Message(
            key: const Key('map-empty'),
            icon: Icons.map_outlined,
            title: l10n.t('map.empty.title'),
            body: l10n.t('map.empty.body'),
          );
        case MapStatus.ready:
          return state.view == MapViewMode.map ? _citiesMap(state) : _citiesList(state);
      }
    }

    switch (state.areasStatus) {
      case AreasStatus.loading:
        return _Loading(label: l10n.t('map.loading'));
      case AreasStatus.error:
        return _Message(
          key: const Key('map-areas-error'),
          icon: offline ? Icons.cloud_off_outlined : Icons.error_outline,
          title: l10n.t(offline ? 'map.offline' : 'map.areas.error'),
          action: _RetryButton(onPressed: notifier.retryAreas),
        );
      case AreasStatus.ready:
        final hasAreas = (state.areas?.areas ?? const []).isNotEmpty;
        if (!hasAreas) return _noAreas(context, state, city);
        return state.view == MapViewMode.map ? _areasMap(state) : _areasList(state);
    }
  }

  // ---- Villes

  Widget _citiesMap(MapState state) {
    final l10n = L10n.of(context);
    final cities = state.cities;
    final spots = citySpots(cities);
    return MapCanvas(
      legend: l10n.t('map.legend.cities'),
      pins: [
        for (var i = 0; i < cities.length; i++)
          MapPinData(
            keyId: 'city-${cities[i].id}',
            label: '${cities[i].name} · ${cities[i].businessesCount}',
            semanticLabel: _fill(l10n.t('map.pin'), {
              'name': cities[i].name,
              'count': _plural(l10n, 'map.commerces', cities[i].businessesCount),
            }),
            spot: spots[i],
            onTap: () => ref.read(mapControllerProvider.notifier).openCity(cities[i]),
          ),
      ],
    );
  }

  Widget _citiesList(MapState state) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final cities = state.filteredCities;
    return Column(
      children: [
        _SearchField(
          controller: _search,
          hint: l10n.t('map.search.cities'),
          onChanged: ref.read(mapControllerProvider.notifier).setQuery,
        ),
        Expanded(
          child: cities.isEmpty
              ? _NoMatch(query: state.query)
              : ListView.separated(
                  key: const Key('map-city-list'),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: cities.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final city = cities[i];
                    final registered = _plural(l10n, 'map.city.registered', city.businessesCount);
                    final region = city.region?.name;
                    return _Row(
                      key: ValueKey('map-city-${city.id}'),
                      title: city.name,
                      subtitle: region == null ? registered : '$region · $registered',
                      color: c,
                      onTap: () => ref.read(mapControllerProvider.notifier).openCity(city),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ---- Quartiers

  Widget _areasMap(MapState state) {
    final l10n = L10n.of(context);
    final areas = state.areas!.areas;
    final spots = gridSpots(areas.length);
    return MapCanvas(
      legend: l10n.t('map.legend.areas'),
      pins: [
        for (var i = 0; i < areas.length; i++)
          MapPinData(
            keyId: 'area-${areas[i].id}',
            label: '${areas[i].name} · ${areas[i].businessesCount}',
            semanticLabel: _fill(l10n.t('map.pin'), {
              'name': areas[i].name,
              'count': _plural(l10n, 'map.commerces', areas[i].businessesCount),
            }),
            spot: spots[i],
            onTap: () => _openArea(areas[i]),
          ),
      ],
    );
  }

  Widget _areasList(MapState state) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final areas = state.filteredAreas;
    return Column(
      children: [
        _SearchField(
          controller: _search,
          hint: l10n.t('map.search.areas'),
          onChanged: ref.read(mapControllerProvider.notifier).setQuery,
        ),
        Expanded(
          child: areas.isEmpty
              ? _NoMatch(query: state.query)
              : ListView.separated(
                  key: const Key('map-area-list'),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: areas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final a = areas[i];
                    return _Row(
                      key: ValueKey('map-area-${a.id}'),
                      title: a.name,
                      subtitle:
                          '${_plural(l10n, 'map.commerces', a.businessesCount)} · ${_plural(l10n, 'map.products', a.productsCount)}',
                      color: c,
                      onTap: () => _openArea(a),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _noAreas(BuildContext context, MapState state, MapCity city) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final count = city.businessesCount;
    final body = _fill(l10n.t(count == 1 ? 'map.noAreas.body.one' : 'map.noAreas.body.other'),
        {'count': count, 'name': city.name});
    final notifier = ref.read(mapControllerProvider.notifier);
    final inMap = state.view == MapViewMode.map;
    final card = Container(
      key: const Key('map-no-areas'),
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: c.background,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.t('map.noAreas.title'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(inMap ? body : '$body — ${l10n.t('map.noAreas.listHint')}',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.textSecondary)),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('map-no-areas-back'),
            onPressed: notifier.backToCities,
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text(l10n.t('map.noAreas.back')),
          ),
        ],
      ),
    );
    if (inMap) return MapCanvas(pins: const [], overlay: card);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [card]);
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.view, required this.onMap, required this.onList});

  final MapViewMode view;
  final VoidCallback onMap;
  final VoidCallback onList;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    Widget tab(Key key, String text, bool selected, VoidCallback onTap) => Expanded(
          child: Semantics(
            button: true,
            selected: selected,
            child: Material(
              color: selected ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                key: key,
                borderRadius: BorderRadius.circular(9),
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Center(
                    child: Text(text,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? AppColors.onAccent : c.textSecondary,
                        )),
                  ),
                ),
              ),
            ),
          ),
        );
    return Semantics(
      container: true,
      label: l10n.t('map.tabs.label'),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            tab(const Key('map-tab-map'), l10n.t('map.tab.map'), view == MapViewMode.map, onMap),
            tab(const Key('map-tab-list'), l10n.t('map.tab.list'), view == MapViewMode.list,
                onList),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: TextField(
        key: const Key('map-search'),
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(Icons.search, color: c.textSecondary),
          filled: true,
          fillColor: c.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: c.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: c.border),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final AppColors color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: color.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: color.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _Message(
      key: const Key('map-no-match'),
      title: _fill(l10n.t('map.search.empty'), {'q': query.trim()}),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          label: label,
          liveRegion: true,
          child: const CircularProgressIndicator(),
        ),
      );
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        key: const Key('map-retry'),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        child: Text(L10n.of(context).t('map.retry')),
      );
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.title, this.body, this.icon, this.action});

  final String title;
  final String? body;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 40, color: c.textSecondary),
              const SizedBox(height: 12),
            ],
            Text(title, textAlign: TextAlign.center, style: text.titleMedium),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body!,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: c.textSecondary)),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
