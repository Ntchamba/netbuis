import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/network/dio_client.dart';
import 'package:netbuis/core/theme/app_theme.dart';
import 'package:netbuis/features/maps/application/map_controller.dart';
import 'package:netbuis/features/maps/application/map_layout.dart';
import 'package:netbuis/features/maps/data/map_repository.dart';
import 'package:netbuis/features/maps/data/map_repository_api.dart';
import 'package:netbuis/features/maps/data/map_repository_fake.dart';
import 'package:netbuis/features/maps/data/models/map_models.dart';
import 'package:netbuis/features/maps/presentation/screens/map_screen.dart';
import 'package:netbuis/features/search/application/offline_controller.dart';
import 'package:netbuis/features/search/data/models/search_result.dart';

import '../auth/auth_test_helpers.dart';
import '../business/business_submit_helpers.dart' show kApiUrl;
import '../call/call_test_helpers.dart';

Map<String, Object?> _cityJson(int id, String name, int count,
        {double? lat, double? lng, String? region = 'Région Nord'}) =>
    {
      'id': id,
      'name': name,
      'latitude': lat,
      'longitude': lng,
      'businesses_count': count,
      'region': region == null ? null : {'id': 9, 'name': region, 'explorable': true},
      'departement': null,
    };

const _kMarouaId = 16;

MapCity _city(int id, String name, int count, {double? lat, double? lng}) =>
    MapCity(id: id, name: name, businessesCount: count, latitude: lat, longitude: lng);

class _ScriptedMap implements MapRepository {
  _ScriptedMap({required List<MapCity> cities}) : list = cities;

  List<MapCity> list;
  ApiException? citiesError;
  ApiException? areasError;
  Future<MapCities>? gate;
  int citiesCalls = 0;
  int areasCalls = 0;

  @override
  Future<MapCities> cities({String q = ''}) async {
    citiesCalls++;
    if (gate != null) return gate!;
    final e = citiesError;
    if (e != null) throw e;
    return MapCities(cities: list, regions: const []);
  }

  @override
  Future<MapAreas> areas(int cityId) async {
    areasCalls++;
    final e = areasError;
    if (e != null) throw e;
    return MapAreas(cityId: cityId, cityName: 'X', areas: const [], businessesWithoutArea: 0);
  }

  @override
  Future<SearchPage> areaBusinesses(int areaId, {int page = 1}) async =>
      const SearchPage(count: 0, results: [], hasNext: false);
}

Future<void> _pump(
  WidgetTester tester,
  MapRepository repo, {
  ThemeData? theme,
  void Function(MapArea)? onOpenArea,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [mapRepositoryProvider.overrideWithValue(repo)],
    child: Theme(
      data: theme ?? AppTheme.light,
      child: testApp(MapScreen(onOpenArea: onOpenArea)),
    ),
  ));
  await tester.pump();
  await tester.pump();
  if (settle) await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('modèles et dépôt api', () {
    test('une ville sans commerce est écartée à la lecture', () {
      final data = MapCities.fromJson({
        'cities': [_cityJson(1, 'Maroua', 91), _cityJson(2, 'Vide', 0)],
        'regions': [
          {'id': 9, 'name': 'Région Nord', 'explorable': true, 'departements': []}
        ],
      });
      expect(data.cities.map((c) => c.name), ['Maroua']);
      expect(data.regions.single.name, 'Région Nord');
    });

    test('réponse cassée -> FormatException', () {
      expect(() => MapCities.fromJson({'cities': 1, 'regions': []}), throwsFormatException);
      expect(() => MapAreas.fromJson({'areas': []}), throwsFormatException);
    });

    test('GET /map/cities/ et /areas/ : lus ; réponse cassée -> ApiException', () async {
      final ok = FakeAdapter((r) {
        if (r.path.endsWith('/areas/')) {
          return FakeAdapter.reply(200, {
            'city': {'id': 16, 'name': 'Maroua'},
            'areas': [
              {'id': 3, 'name': 'Hardé', 'businesses_count': 24, 'products_count': 61}
            ],
            'businesses_without_area': 2,
          });
        }
        return FakeAdapter.reply(200, {
          'cities': [_cityJson(16, 'Maroua', 5, lat: 10.6, lng: 14.3)],
          'regions': [],
        });
      });
      final repo = MapRepositoryApi(
          buildDio(baseUrl: kApiUrl, readAccessToken: () async => 'acc-test')
            ..httpClientAdapter = ok);
      final cities = await repo.cities(q: 'mar');
      expect(ok.seen.single.path, '/map/cities/');
      expect(cities.cities.single.latitude, 10.6);
      final areas = await repo.areas(16);
      expect(ok.seen.last.path, '/map/cities/16/areas/');
      expect(areas.areas.single.productsCount, 61);
      expect(areas.businessesWithoutArea, 2);

      final bad = MapRepositoryApi(
          buildDio(baseUrl: kApiUrl, readAccessToken: () async => 'acc-test')
            ..httpClientAdapter = FakeAdapter((r) => FakeAdapter.reply(200, {'oops': 1})));
      await expectLater(bad.cities(), throwsA(isA<ApiException>()));
    });

    test('dépôt factice : villes actives seulement, quartiers de Maroua', () async {
      final repo = MapRepositoryFake();
      final cities = await repo.cities();
      expect(cities.cities.every((c) => c.businessesCount > 0), isTrue);
      expect((await repo.cities(q: 'gar')).cities.single.name, 'Garoua');
      expect((await repo.areas(_kMarouaId)).areas, hasLength(4));
      expect((await repo.areas(17)).areas, isEmpty);
      await expectLater(repo.areas(999), throwsA(isA<ApiException>()));
    });
  });

  group('positions indicatives', () {
    test('grille : tous dans le cadre, tous distincts', () {
      final spots = gridSpots(5);
      expect(spots, hasLength(5));
      expect(spots.every((s) => s.x > 0 && s.x < 1 && s.y > 0 && s.y < 1), isTrue);
      expect({for (final s in spots) '${s.x}/${s.y}'}, hasLength(5));
      expect(gridSpots(0), isEmpty);
    });

    test('coordonnées utilisées quand toutes les villes en ont : le nord est en haut', () {
      final cities = [
        _city(1, 'Nord', 3, lat: 9.3, lng: 13.4),
        _city(2, 'Sud', 3, lat: 4.0, lng: 9.7),
      ];
      expect(usesCoordinates(cities), isTrue);
      final s = citySpots(cities);
      expect(s[0].y, lessThan(s[1].y));
      expect(s[0].x, greaterThan(s[1].x));
    });

    test('une ville sans coordonnées : grille pour toutes', () {
      final cities = [_city(1, 'A', 3, lat: 9.3, lng: 13.4), _city(2, 'B', 3)];
      expect(usesCoordinates(cities), isFalse);
      expect(citySpots(cities).map((s) => s.x), gridSpots(2).map((s) => s.x));
    });
  });

  group('écran Carte', () {
    testWidgets('mode Carte : titre, libellé, légende, une épingle par ville active', (tester) async {
      await _pump(tester, MapRepositoryFake());
      expect(find.text('Explorer'), findsOneWidget);
      expect(find.text('Cameroun · 3 villes actives'), findsOneWidget);
      expect(find.byKey(const Key('map-tab-map')), findsOneWidget);
      expect(find.byKey(const Key('map-tab-list')), findsOneWidget);
      expect(find.text('Maroua · 91'), findsOneWidget);
      expect(find.text('Garoua · 14'), findsOneWidget);
      expect(find.text('Douala · 8'), findsOneWidget);
      expect(find.textContaining('Seules les villes/villages'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('aucune ville sans commerce n\'apparaît (carte et liste)', (tester) async {
      final repo = _ScriptedMap(cities: [_city(1, 'Maroua', 4), _city(2, 'Villevide', 0)]);
      await _pump(tester, repo);
      expect(find.textContaining('Villevide'), findsNothing);
      await tester.tap(find.byKey(const Key('map-tab-list')));
      await tester.pump();
      expect(find.text('Maroua'), findsOneWidget);
      expect(find.text('Villevide'), findsNothing);
      expect(find.text('Cameroun · 1 ville active'), findsOneWidget);
    });

    testWidgets('mode Liste : région et nombre de commerces, recherche locale', (tester) async {
      await _pump(tester, MapRepositoryFake());
      await tester.tap(find.byKey(const Key('map-tab-list')));
      await tester.pump();
      expect(find.text('Région Extrême-Nord · 91 commerces enregistrés'), findsOneWidget);
      expect(find.text('Région Nord · 14 commerces enregistrés'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('map-search')), 'GAR');
      await tester.pump();
      expect(find.text('Garoua'), findsOneWidget);
      expect(find.text('Maroua'), findsNothing);

      await tester.enterText(find.byKey(const Key('map-search')), 'zzz');
      await tester.pump();
      expect(find.byKey(const Key('map-no-match')), findsOneWidget);
    });

    testWidgets('ouvrir une ville : quartiers avec compteurs, légende, retour', (tester) async {
      await _pump(tester, MapRepositoryFake());
      await tester.tap(find.byKey(const Key('map-pin-city-16')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Maroua, Région Extrême-Nord'), findsOneWidget);
      expect(find.text('Hardé · 24'), findsOneWidget);
      expect(find.text('Dougoï · 38'), findsOneWidget);
      expect(find.text('Positions indicatives — pas encore géolocalisées'), findsOneWidget);

      await tester.tap(find.byKey(const Key('map-tab-list')));
      await tester.pump();
      expect(find.text('24 commerces · 61 produits référencés'), findsOneWidget);

      await tester.tap(find.byKey(const Key('map-back')));
      await tester.pump();
      expect(find.text('Cameroun · 3 villes actives'), findsOneWidget);
    });

    testWidgets('toucher un quartier appelle le point d\'entrée (T062)', (tester) async {
      MapArea? opened;
      await _pump(tester, MapRepositoryFake(), onOpenArea: (a) => opened = a);
      await tester.tap(find.byKey(const Key('map-pin-city-16')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('map-pin-area-302')));
      expect(opened?.name, 'Dougoï');
    });

    testWidgets('ville sans quartier : encart « Pas encore de détail par quartier »', (tester) async {
      await _pump(tester, MapRepositoryFake());
      await tester.tap(find.byKey(const Key('map-pin-city-17')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Pas encore de détail par quartier'), findsOneWidget);
      expect(find.text('14 commerces déjà enregistrés à Garoua'), findsOneWidget);
      await tester.tap(find.byKey(const Key('map-tab-list')));
      await tester.pump();
      expect(find.textContaining('Utilisez la recherche'), findsOneWidget);
      await tester.tap(find.byKey(const Key('map-no-areas-back')));
      await tester.pump();
      expect(find.text('Cameroun · 3 villes actives'), findsOneWidget);
    });

    testWidgets('chargement puis vide', (tester) async {
      final gate = Completer<MapCities>();
      final repo = _ScriptedMap(cities: const [])..gate = gate.future;
      await _pump(tester, repo, settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete(const MapCities(cities: [], regions: []));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('map-empty')), findsOneWidget);
      expect(find.textContaining('Aucune ville'), findsOneWidget);
    });

    testWidgets('erreur : Réessayer recharge et affiche les villes', (tester) async {
      final repo = _ScriptedMap(cities: [_city(1, 'Maroua', 4)])
        ..citiesError = const ApiException(ApiErrorCode.unknown);
      await _pump(tester, repo);
      expect(find.byKey(const Key('map-error')), findsOneWidget);
      expect(find.text('La carte n\'a pas pu être chargée.'), findsOneWidget);
      repo.citiesError = null;
      await tester.tap(find.byKey(const Key('map-retry')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('map-error')), findsNothing);
      expect(find.text('Maroua · 4'), findsOneWidget);
    });

    testWidgets('hors connexion : message simple et Réessayer', (tester) async {
      final repo = _ScriptedMap(cities: [_city(1, 'Maroua', 4)])
        ..citiesError = const ApiException(ApiErrorCode.network);
      await _pump(tester, repo);
      expect(find.text('Pas de réseau : la carte est indisponible pour le moment.'),
          findsOneWidget);
      expect(find.byKey(const Key('map-retry')), findsOneWidget);
    });

    testWidgets('erreur des quartiers : message et Réessayer', (tester) async {
      final repo = _ScriptedMap(cities: [_city(1, 'Maroua', 4)])
        ..areasError = const ApiException(ApiErrorCode.unknown);
      await _pump(tester, repo);
      await tester.tap(find.byKey(const Key('map-pin-city-1')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('map-areas-error')), findsOneWidget);
      repo.areasError = null;
      await tester.tap(find.byKey(const Key('map-retry')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('map-areas-error')), findsNothing);
      expect(find.byKey(const Key('map-no-areas')), findsOneWidget);
    });

    testWidgets('thème sombre : aucun débordement, pastille de ville présente', (tester) async {
      await _pump(tester, MapRepositoryFake(), theme: AppTheme.dark);
      expect(find.byKey(const Key('map-canvas')), findsOneWidget);
      expect(find.text('Maroua · 91'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('aucun numéro de téléphone dans l\'arbre', (tester) async {
      await _pump(tester, MapRepositoryFake());
      await tester.tap(find.byKey(const Key('map-tab-list')));
      await tester.pump();
      expect(find.textContaining(RegExp(r'\+?237|\b6\d{8}\b')), findsNothing);
    });
  });

  test('foldName ignore casse et accents', () {
    expect(foldName('  Hardé '), 'harde');
    expect(foldName('DOUGOÏ'), 'dougoi');
  });

  test('offlineProvider passe à vrai sur une coupure réseau', () async {
    final repo = _ScriptedMap(cities: const [])
      ..citiesError = const ApiException(ApiErrorCode.network);
    final container = ProviderContainer(overrides: [mapRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    final sub = container.listen(mapControllerProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(sub.read().status, MapStatus.error);
    expect(container.read(offlineProvider), isTrue);
  });
}
