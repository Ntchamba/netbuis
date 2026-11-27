import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/l10n/l10n.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/storage/prefs.dart';
import 'package:netbuis/core/theme/app_theme.dart';
import 'package:netbuis/features/search/application/search_controller.dart';
import 'package:netbuis/features/search/data/models/search_query.dart';
import 'package:netbuis/features/search/data/repositories/search_repository_fake.dart';
import 'package:netbuis/features/search/data/models/search_result.dart';
import 'package:netbuis/features/onboarding/application/city_controller.dart';
import 'package:netbuis/core/data/zones/zone.dart';
import 'package:netbuis/features/search/data/search_cache.dart';
import 'package:netbuis/features/trends/application/trends_controller.dart';
import 'package:netbuis/features/trends/data/models/trend.dart';
import 'package:netbuis/features/trends/data/repositories/trends_repository.dart';
import 'package:netbuis/features/trends/data/repositories/trends_repository_fake.dart';
import 'package:netbuis/features/trends/presentation/widgets/trending_section.dart';

import '../auth/login_test_helpers.dart' show MemoryPrefs;

Map<String, Object?> _json({
  int n = 2,
  int nb = 2,
  Object? zone = const {'id': 16, 'name': 'Maroua'},
}) =>
    {
      'zone': zone,
      'computed_at': '2026-01-01T03:00:00Z',
      'period_days': 7,
      'products': [
        for (var i = 0; i < n; i++) {'id': i + 1, 'name': 'Produit ${i + 1}', 'rank': i + 1},
      ],
      'businesses': [
        for (var i = 0; i < nb; i++)
          {
            'id': 100 + i,
            'name': 'Commerce ${i + 1}',
            'zone': {'id': 17, 'name': 'Hardé'},
            'rank': i + 1
          },
      ],
    };

class _Repo implements TrendsRepository {
  _Repo(this.trends);
  Trends trends;
  bool fail = false;
  final List<int> calls = [];

  @override
  Future<Trends> getTrends(int zone) async {
    calls.add(zone);
    if (fail) throw const ApiException(ApiErrorCode.network);
    return trends;
  }
}

class _Search extends SearchRepositoryFake {
  final List<SearchQuery> queries = [];

  @override
  Future<SearchPage> search(SearchQuery query, {int page = 1}) {
    queries.add(query);
    return super.search(query, page: page);
  }
}

Trends _many(int n, int nb) => Trends.fromJson(_json(n: n, nb: nb));

Future<_Search> _pump(
  WidgetTester tester,
  TrendsRepository repo, {
  AppPrefs? prefs,
  ThemeMode mode = ThemeMode.dark,
  double scale = 1.0,
  ValueChanged<String>? onProduct,
  ValueChanged<int>? onBusiness,
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final search = _Search();
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: TrendingSection(onProductTap: onProduct, onBusinessTap: onBusiness),
        ),
      ),
    ),
    GoRoute(path: '/search', builder: (_, __) => const Scaffold(body: Text('PAGE-RECHERCHE'))),
    GoRoute(
        path: '/business/:id',
        builder: (_, s) => Scaffold(body: Text('FICHE-${s.pathParameters['id']}'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appPrefsProvider.overrideWithValue(prefs ?? MemoryPrefs()),
      trendsRepositoryProvider.overrideWithValue(repo),
      searchRepositoryProvider.overrideWithValue(search),
      searchCacheProvider.overrideWithValue(MemorySearchCache()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      locale: const Locale('fr'),
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
  return search;
}

void main() {
  group('modèle', () {
    test('lit la réponse du contrat et ignore les champs inattendus', () {
      final json = _json();
      json['extra'] = 1;
      ((json['products']! as List)[0] as Map)['count'] = 99;
      ((json['businesses']! as List)[0] as Map)['phone'] = '+237600000000';
      final t = Trends.fromJson(json);
      expect(t.zoneId, 16);
      expect(t.zoneName, 'Maroua');
      expect(t.periodDays, 7);
      expect(t.computedAt, DateTime.utc(2026, 1, 1, 3));
      expect(t.products.map((p) => p.name), ['Produit 1', 'Produit 2']);
      expect(t.businesses.first.zoneName, 'Hardé');
      expect(t.businesses.first.id, 100);
    });

    test('zone absente et listes vides : vide', () {
      final t = Trends.fromJson({
        'zone': null,
        'computed_at': null,
        'period_days': null,
        'products': <Object?>[],
        'businesses': <Object?>[],
      });
      expect(t.isEmpty, isTrue);
      expect(t.zoneId, isNull);
    });

    test('trie par rang et écarte un élément mal formé', () {
      final t = Trends.fromJson({
        'zone': null,
        'computed_at': null,
        'period_days': null,
        'products': [
          {'id': 2, 'name': 'B', 'rank': 2},
          {'id': 'x', 'name': 'Cassé', 'rank': 3},
          {'id': 1, 'name': 'A', 'rank': 1},
        ],
        'businesses': <Object?>[],
      });
      expect(t.products.map((p) => p.name), ['A', 'B']);
    });

    test('réponse qui n\'a pas la forme du contrat : FormatException', () {
      expect(() => Trends.fromJson({'zone': 5, 'products': [], 'businesses': []}),
          throwsFormatException);
      expect(() => Trends.fromJson({'zone': null}), throwsFormatException);
    });

    test('le dépôt factice ne contient ni numéro ni chiffre de téléphone', () async {
      final t = await const TrendsRepositoryFake().getTrends(16);
      final text = [
        for (final p in t.products) p.name,
        for (final b in t.businesses) '${b.name} ${b.zoneName}',
      ].join(' ');
      expect(RegExp(r'\d{6,}').hasMatch(text), isFalse);
      expect(t.products, isNotEmpty);
    });
  });

  group('état (trendsProvider)', () {
    test('zone absente : vide, sans appel au serveur', () async {
      final repo = _Repo(_many(3, 1));
      final c = ProviderContainer(overrides: [trendsRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);
      expect((await c.read(trendsProvider(null).future)).isEmpty, isTrue);
      expect(repo.calls, isEmpty);
    });

    test('erreur réseau : vide, sans exception', () async {
      final repo = _Repo(_many(3, 1))..fail = true;
      final c = ProviderContainer(overrides: [trendsRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);
      final sub = c.listen(trendsProvider(16), (_, __) {});
      expect((await c.read(trendsProvider(16).future)).isEmpty, isTrue);
      sub.close();
    });

    test('succès gardé en mémoire, puis rafraîchissement', () async {
      final repo = _Repo(_many(3, 1));
      final c = ProviderContainer(overrides: [trendsRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);
      expect((await c.read(trendsProvider(16).future)).products, hasLength(3));
      await Future<void>.delayed(Duration.zero);
      expect((await c.read(trendsProvider(16).future)).products, hasLength(3));
      expect(repo.calls, [16]);
      repo.trends = _many(1, 1);
      c.invalidate(trendsProvider(16));
      expect((await c.read(trendsProvider(16).future)).products, hasLength(1));
      expect(repo.calls, [16, 16]);
    });
  });

  group('bande', () {
    testWidgets('6 produits au plus et 3 commerces au plus', (tester) async {
      await _pump(tester, _Repo(_many(10, 10)));
      expect(find.text('Très demandé près de chez vous'), findsOneWidget);
      expect(find.text('Commerces très contactés'), findsOneWidget);
      expect(find.text('Produit 6'), findsOneWidget);
      expect(find.text('Produit 7'), findsNothing);
      expect(find.text('Commerce 3'), findsOneWidget);
      expect(find.text('Commerce 4'), findsNothing);
      expect(find.text('Hardé'), findsNWidgets(3));
      expect(find.byIcon(Icons.trending_up), findsNWidgets(6));
    });

    testWidgets('un seul des deux blocs : l\'autre est absent', (tester) async {
      await _pump(tester, _Repo(_many(2, 0)));
      expect(find.text('Très demandé près de chez vous'), findsOneWidget);
      expect(find.text('Commerces très contactés'), findsNothing);
    });

    testWidgets('masquée si les deux listes sont vides', (tester) async {
      await _pump(tester, _Repo(Trends.empty));
      expect(find.text('Très demandé près de chez vous'), findsNothing);
      expect(find.text('Commerces très contactés'), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('erreur réseau : masquée, sans message ni exception', (tester) async {
      await _pump(tester, _Repo(_many(3, 3))..fail = true);
      expect(find.text('Très demandé près de chez vous'), findsNothing);
      expect(find.byType(Text), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('aucune ville choisie : masquée, sans appel', (tester) async {
      final repo = _Repo(_many(3, 3));
      await _pump(tester, repo, prefs: MemoryPrefs(city: null));
      expect(find.byType(Text), findsNothing);
      expect(repo.calls, isEmpty);
    });

    testWidgets('la zone envoyée est la ville choisie', (tester) async {
      final repo = _Repo(_many(1, 1));
      await _pump(tester, repo);
      expect(repo.calls, [16]);
    });

    testWidgets('toucher un produit lance la recherche avec ce terme', (tester) async {
      final search = await _pump(tester, _Repo(_many(3, 1)));
      await tester.tap(find.text('Produit 2'));
      await tester.pumpAndSettle();
      expect(find.text('PAGE-RECHERCHE'), findsOneWidget);
      expect(search.queries.last.q, 'Produit 2');
      expect(search.queries.last.zone, 16);
    });

    testWidgets('secteur actif et autre zone : le toucher cherche sans secteur, dans la zone de la bande',
        (tester) async {
      final search = await _pump(tester, _Repo(_many(3, 1)));
      final container = ProviderScope.containerOf(tester.element(find.byType(TrendingSection)));
      final ctrl = container.read(searchControllerProvider.notifier);
      ctrl.setSector('pharmacie_sante');
      ctrl.setZone(18);
      await tester.pumpAndSettle();
      expect(search.queries.last.sector, 'pharmacie_sante');
      expect(search.queries.last.zone, 18);
      await tester.tap(find.text('Produit 2'));
      await tester.pumpAndSettle();
      expect(search.queries.last.q, 'Produit 2');
      expect(search.queries.last.sector, isNull);
      expect(search.queries.last.zone, 16);
      expect(container.read(searchControllerProvider).query,
          const SearchQuery(q: 'Produit 2', zone: 16));
    });

    testWidgets('changement de ville : tendances de la nouvelle ville', (tester) async {
      final repo = _Repo(_many(2, 1));
      await _pump(tester, repo);
      expect(repo.calls, [16]);
      final container = ProviderScope.containerOf(tester.element(find.byType(TrendingSection)));
      await container
          .read(selectedCityProvider.notifier)
          .select(const Zone(id: 30, name: 'Garoua', level: ZoneLevel.villeVillage));
      repo.trends = Trends.fromJson({
        'zone': {'id': 30, 'name': 'Garoua'},
        'computed_at': null,
        'period_days': 7,
        'products': [
          {'id': 9, 'name': 'Coton', 'rank': 1}
        ],
        'businesses': <Object?>[],
      });
      await tester.pumpAndSettle();
      expect(repo.calls, [16, 30]);
      expect(find.text('Coton'), findsOneWidget);
      expect(find.text('Produit 1'), findsNothing);
      await tester.tap(find.text('Coton'));
      await tester.pumpAndSettle();
    });

    testWidgets('toucher un commerce ouvre sa fiche', (tester) async {
      await _pump(tester, _Repo(_many(3, 3)));
      await tester.tap(find.text('Commerce 2'));
      await tester.pumpAndSettle();
      expect(find.text('FICHE-101'), findsOneWidget);
    });

    testWidgets('les rappels fournis remplacent le comportement par défaut', (tester) async {
      final names = <String>[];
      final ids = <int>[];
      await _pump(tester, _Repo(_many(3, 3)), onProduct: names.add, onBusiness: ids.add);
      await tester.tap(find.text('Produit 1'));
      await tester.tap(find.text('Commerce 1'));
      expect(names, ['Produit 1']);
      expect(ids, [100]);
      expect(find.text('PAGE-RECHERCHE'), findsNothing);
    });

    testWidgets('aucun numéro de téléphone affiché', (tester) async {
      final json = _json(n: 3, nb: 3);
      ((json['businesses']! as List)[0] as Map)['phone'] = '+237677001122';
      await _pump(tester, _Repo(Trends.fromJson(json)));
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join(' ');
      expect(texts.contains('237'), isFalse);
      expect(RegExp(r'\d{6,}').hasMatch(texts), isFalse);
    });

    testWidgets('accessibilité : étiquettes lues par le lecteur d\'écran', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _Repo(_many(2, 1)));
      expect(find.bySemanticsLabel('Chercher Produit 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Ouvrir la fiche de Commerce 1, Hardé'), findsOneWidget);
      handle.dispose();
    });

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('police 130 % à 360 px sans débordement (${mode.name})', (tester) async {
        final json = _json(n: 6, nb: 3);
        ((json['products']! as List)[0] as Map)['name'] =
            'Une très longue désignation de produit sans fin réaliste pour tester la coupure';
        ((json['businesses']! as List)[0] as Map)['name'] =
            'Établissement au nom particulièrement long pour la rangée';
        await _pump(tester, _Repo(Trends.fromJson(json)), scale: 1.3, mode: mode);
        expect(tester.takeException(), isNull);
        final width = tester.getSize(find.byKey(const Key('trending-products'))).width;
        expect(width, lessThanOrEqualTo(360));
        for (final chip in tester.widgetList(find.descendant(
            of: find.byKey(const Key('trending-products')), matching: find.byType(InkWell)))) {
          final r = tester.getRect(find.byWidget(chip));
          expect(r.right, lessThanOrEqualTo(360));
          expect(r.height, greaterThanOrEqualTo(48));
        }
      });
    }
  });
}
