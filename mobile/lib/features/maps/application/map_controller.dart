// État de l'écran Carte : villes actives, bascule Carte / Liste, ville ouverte et ses quartiers,
// recherche (filtre local sur les villes déjà chargées, y compris hors connexion).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/di/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../search/application/offline_controller.dart';
import '../data/map_repository.dart';
import '../data/map_repository_api.dart';
import '../data/map_repository_fake.dart';
import '../data/models/map_models.dart';

/// Dépôt de la carte : factice si `USE_FAKE_API=true`, sinon relié à l'API.
final mapRepositoryProvider = Provider<MapRepository>((ref) {
  if (Env.useFakeApi) return MapRepositoryFake();
  return MapRepositoryApi(ref.read(dioProvider));
});

enum MapViewMode { map, list }

enum MapStatus { loading, ready, empty, error }

enum AreasStatus { loading, ready, error }

/// Minuscules sans accents, pour comparer des noms.
String foldName(String s) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final buf = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final i = from.indexOf(ch);
    buf.write(i >= 0 ? to[i] : ch);
  }
  return buf.toString().trim();
}

class MapState {
  const MapState({
    this.view = MapViewMode.map,
    this.status = MapStatus.loading,
    this.cities = const [],
    this.error,
    this.activeCity,
    this.areasStatus = AreasStatus.loading,
    this.areas,
    this.areasError,
    this.query = '',
  });

  final MapViewMode view;
  final MapStatus status;
  final List<MapCity> cities;
  final ApiException? error;

  /// Ville ouverte (étape « quartiers »), ou null (étape « villes »).
  final MapCity? activeCity;
  final AreasStatus areasStatus;
  final MapAreas? areas;
  final ApiException? areasError;
  final String query;

  bool get inCity => activeCity != null;

  /// Villes de la liste, filtrées par la recherche.
  List<MapCity> get filteredCities {
    final q = foldName(query);
    if (q.isEmpty) return cities;
    return [for (final c in cities) if (foldName(c.name).contains(q)) c];
  }

  /// Quartiers de la ville ouverte, filtrés par la recherche.
  List<MapArea> get filteredAreas {
    final all = areas?.areas ?? const <MapArea>[];
    final q = foldName(query);
    if (q.isEmpty) return all;
    return [for (final a in all) if (foldName(a.name).contains(q)) a];
  }

  MapState copyWith({
    MapViewMode? view,
    MapStatus? status,
    List<MapCity>? cities,
    ApiException? error,
    MapCity? activeCity,
    bool clearActiveCity = false,
    AreasStatus? areasStatus,
    MapAreas? areas,
    bool clearAreas = false,
    ApiException? areasError,
    String? query,
  }) =>
      MapState(
        view: view ?? this.view,
        status: status ?? this.status,
        cities: cities ?? this.cities,
        error: error ?? this.error,
        activeCity: clearActiveCity ? null : (activeCity ?? this.activeCity),
        areasStatus: areasStatus ?? this.areasStatus,
        areas: clearAreas ? null : (areas ?? this.areas),
        areasError: areasError ?? this.areasError,
        query: query ?? this.query,
      );
}

final mapControllerProvider =
    NotifierProvider.autoDispose<MapController, MapState>(MapController.new);

class MapController extends Notifier<MapState> {
  int _citiesTicket = 0;
  int _areasTicket = 0;

  @override
  MapState build() {
    ref.onDispose(() {
      _citiesTicket++;
      _areasTicket++;
    });
    Future.microtask(() {
      if (ref.mounted && state.status == MapStatus.loading) _loadCities();
    });
    return const MapState();
  }

  MapRepository get _repo => ref.read(mapRepositoryProvider);

  void _markOffline(ApiException e) {
    if (e.code == ApiErrorCode.network) ref.read(offlineProvider.notifier).set(true);
  }

  /// « Réessayer » après une erreur de la liste des villes.
  Future<void> retry() {
    state = state.copyWith(status: MapStatus.loading);
    return _loadCities();
  }

  Future<void> _loadCities() async {
    final ticket = ++_citiesTicket;
    try {
      final data = await _repo.cities();
      if (!ref.mounted || ticket != _citiesTicket) return;
      ref.read(offlineProvider.notifier).set(false);
      // Une ville sans commerce n'apparaît jamais (déjà écartée à la lecture ; on revérifie).
      final cities = [for (final c in data.cities) if (c.businessesCount > 0) c];
      state = state.copyWith(
        status: cities.isEmpty ? MapStatus.empty : MapStatus.ready,
        cities: cities,
      );
    } on ApiException catch (e) {
      if (!ref.mounted || ticket != _citiesTicket) return;
      _markOffline(e);
      state = state.copyWith(status: MapStatus.error, error: e);
    }
  }

  void showMap() => state = state.copyWith(view: MapViewMode.map);

  void showList() => state = state.copyWith(view: MapViewMode.list);

  void setQuery(String value) => state = state.copyWith(query: value);

  /// Ouvre une ville : ses quartiers se chargent, la vue repasse sur la carte (comme la maquette).
  Future<void> openCity(MapCity city) {
    state = state.copyWith(
      activeCity: city,
      view: MapViewMode.map,
      areasStatus: AreasStatus.loading,
      clearAreas: true,
      query: '',
    );
    return _loadAreas(city);
  }

  Future<void> retryAreas() {
    final city = state.activeCity;
    if (city == null) return Future.value();
    state = state.copyWith(areasStatus: AreasStatus.loading);
    return _loadAreas(city);
  }

  Future<void> _loadAreas(MapCity city) async {
    final ticket = ++_areasTicket;
    try {
      final data = await _repo.areas(city.id);
      if (!ref.mounted || ticket != _areasTicket) return;
      ref.read(offlineProvider.notifier).set(false);
      state = state.copyWith(areasStatus: AreasStatus.ready, areas: data);
    } on ApiException catch (e) {
      if (!ref.mounted || ticket != _areasTicket) return;
      _markOffline(e);
      state = state.copyWith(areasStatus: AreasStatus.error, areasError: e);
    }
  }

  /// Retour à la liste des villes.
  void backToCities() {
    _areasTicket++;
    state = state.copyWith(
      clearActiveCity: true,
      clearAreas: true,
      view: MapViewMode.map,
      query: '',
    );
  }
}
