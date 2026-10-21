// T062 : écran Quartier — liste, appel (ligne transmise), pagination, vide, erreur, hors connexion.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:netbuis/core/l10n/l10n.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/core/theme/app_theme.dart';
import 'package:netbuis/features/call/data/models/call_session.dart';
import 'package:netbuis/features/maps/application/map_controller.dart';
import 'package:netbuis/features/maps/data/map_repository.dart';
import 'package:netbuis/features/maps/data/models/map_models.dart';
import 'package:netbuis/features/maps/presentation/screens/area_screen.dart';
import 'package:netbuis/features/search/application/offline_controller.dart';
import 'package:netbuis/features/search/data/models/search_result.dart';

import '../call/call_test_helpers.dart';

class _Repo implements MapRepository {
  _Repo({this.total = 12});

  final int total;
  ApiException? error;
  ApiException? pageTwoError;
  final List<int> pages = [];

  @override
  Future<SearchPage> areaBusinesses(int areaId, {int page = 1}) async {
    pages.add(page);
    final e = page == 1 ? error : pageTwoError;
    if (e != null) throw e;
    const size = 10;
    final from = (page - 1) * size;
    final to = from + size > total ? total : from + size;
    return SearchPage(
      count: total,
      hasNext: to < total,
      results: [
        for (var i = from; i < to; i++)
          SearchResult(
            id: 100 + i,
            name: 'Commerce $i',
            kind: 'produit',
            zone: const ResultZone(id: 301, name: 'Hardé'),
            descriptionActivite: 'Activité $i',
          ),
      ],
    );
  }

  @override
  Future<MapCities> cities({String q = ''}) async =>
      const MapCities(cities: [], regions: []);

  @override
  Future<MapAreas> areas(int cityId) async => MapAreas(
      cityId: cityId,
      cityName: 'Maroua',
      areas: const [],
      businessesWithoutArea: 0);
}

class _Off extends OfflineController {
  _Off(this.value);
  final bool value;
  @override
  bool build() => value;

  /// Reste hors connexion même après la première charge réussie.
  @override
  void set(bool v) {}
}

Future<void> _pump(
  WidgetTester tester, {
  required _Repo repo,
  FakeCallChannel? channel,
  FakeCallRepository? calls,
  bool offline = false,
  ThemeMode mode = ThemeMode.light,
  AreaArgs? args =
      const AreaArgs(areaName: 'Hardé', cityId: 16, cityName: 'Maroua'),
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: '/start', routes: [
    GoRoute(
        path: '/start',
        builder: (_, __) => const Scaffold(body: Text('page-quartiers'))),
    GoRoute(
        path: Routes.map,
        builder: (_, __) => const Scaffold(body: Text('page-carte'))),
    GoRoute(
      path: '/area',
      builder: (_, __) => AreaScreen(areaId: 301, args: args),
    ),
    GoRoute(
      path: Routes.businessDetail,
      builder: (_, s) =>
          Scaffold(body: Text('fiche-${s.pathParameters['id']}')),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      mapRepositoryProvider.overrideWithValue(repo),
      if (offline) offlineProvider.overrideWith(() => _Off(true)),
      ...callOverrides(
          channel ?? FakeCallChannel(), calls ?? FakeCallRepository()),
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
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
  router.push('/area');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('liste : fil d\'Ariane, titre, cartes sans numéro',
      (tester) async {
    await _pump(tester, repo: _Repo());
    expect(find.text('Cameroun'), findsOneWidget);
    expect(find.text('Maroua'), findsOneWidget);
    expect(find.byKey(const Key('area-title')), findsOneWidget);
    expect(find.text('Hardé'), findsWidgets);
    expect(find.text('Commerce 0'), findsOneWidget);
    expect(find.text('Appeler'), findsWidgets);
    expectNoPhoneOnScreen(tester);
  });

  testWidgets(
      'fil d\'Ariane : la ville et « Quartiers » ramènent en arrière, le pays à la carte',
      (tester) async {
    await _pump(tester, repo: _Repo());
    await tester.tap(find.byKey(const Key('area-crumb-city')));
    await tester.pumpAndSettle();
    expect(find.text('page-quartiers'), findsOneWidget);

    await _pump(tester, repo: _Repo());
    await tester.tap(find.byKey(const Key('area-crumb-country')));
    await tester.pumpAndSettle();
    expect(find.text('page-carte'), findsOneWidget);
  });

  testWidgets('lien direct sans nom : titre générique, pays seul',
      (tester) async {
    await _pump(tester, repo: _Repo(), args: null);
    expect(find.text('Quartier'), findsOneWidget);
    expect(find.byKey(const Key('area-crumb-city')), findsNothing);
    expect(find.byKey(const Key('area-crumb-country')), findsOneWidget);
  });

  testWidgets('appel : feuille Orange/MTN, la ligne choisie est transmise',
      (tester) async {
    final calls = FakeCallRepository();
    final channel = FakeCallChannel();
    await _pump(tester, repo: _Repo(), channel: channel, calls: calls);
    await tester.tap(find.byType(FilledButton).first);
    await settleSheet(tester);
    expect(find.byKey(const Key('call-choose')), findsOneWidget);
    expect(calls.requests, isEmpty);
    await tester.tap(find.byKey(const Key('call-mtn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls.requests, [(businessId: 100, line: CallLine.mtn)]);
    expect(channel.placed.single.accountId, 'tel|mtn');
    expectNoPhoneOnScreen(tester);
    await closeSheet(tester);
    await dismissFeedback(tester);
  });

  testWidgets('tap sur une carte : fiche publique du commerce', (tester) async {
    await _pump(tester, repo: _Repo());
    await tester.tap(find.text('Commerce 1'));
    await tester.pumpAndSettle();
    expect(find.text('fiche-101'), findsOneWidget);
  });

  testWidgets('pagination : la page 2 se charge en bas de liste, sans doublon',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo: repo);
    expect(repo.pages, [1]);
    expect(find.text('Commerce 11'), findsNothing);
    await tester.drag(
        find.byKey(const Key('area-results')), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(repo.pages, [1, 2]);
    await tester.drag(
        find.byKey(const Key('area-results')), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Commerce 11'), findsOneWidget);
    expect(repo.pages, [1, 2]);
  });

  testWidgets('pagination : échec de la page 2, Réessayer', (tester) async {
    final repo = _Repo()
      ..pageTwoError = const ApiException(ApiErrorCode.unknown);
    await _pump(tester, repo: repo);
    await tester.drag(
        find.byKey(const Key('area-results')), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('area-more-error')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('area-retry-more')));
    await tester.pumpAndSettle();
    repo.pageTwoError = null;
    await tester.tap(find.byKey(const Key('area-retry-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('area-more-error')), findsNothing);
    expect(repo.pages.last, 2);
    expect(find.text('Commerce 10'), findsOneWidget);
  });

  testWidgets('vide : message « aucun commerce dans ce quartier »',
      (tester) async {
    await _pump(tester, repo: _Repo(total: 0));
    expect(find.byKey(const Key('area-empty')), findsOneWidget);
    expect(find.text('Aucun commerce dans ce quartier pour l\'instant.'),
        findsOneWidget);
    expect(find.byKey(const Key('area-results')), findsNothing);
  });

  testWidgets('erreur : message et Réessayer recharge', (tester) async {
    final repo = _Repo()..error = const ApiException(ApiErrorCode.unknown);
    await _pump(tester, repo: repo);
    expect(find.byKey(const Key('area-error')), findsOneWidget);
    repo.error = null;
    await tester.tap(find.byKey(const Key('area-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('area-error')), findsNothing);
    expect(find.text('Commerce 0'), findsOneWidget);
  });

  testWidgets('erreur réseau : bascule hors connexion', (tester) async {
    final repo = _Repo()..error = const ApiException(ApiErrorCode.network);
    await _pump(tester, repo: repo);
    expect(find.byKey(const Key('area-error')), findsOneWidget);
    expect(find.textContaining('Pas de réseau'), findsOneWidget);
  });

  testWidgets(
      'hors connexion : Appeler et WhatsApp désactivés, message affiché, rien ne part',
      (tester) async {
    final calls = FakeCallRepository();
    await _pump(tester, repo: _Repo(), offline: true, calls: calls);
    expect(find.byKey(const Key('area-results')), findsOneWidget);
    expect(find.byKey(const Key('area-offline')), findsOneWidget);
    expect(find.byKey(const Key('card-call-offline')), findsWidgets);
    expect(
        tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(find.descendant(
                of: find.byKey(const Key('card-whatsapp')).first,
                matching: find.byType(OutlinedButton)))
            .onPressed,
        isNull);
    expect(calls.requests, isEmpty);
  });

  testWidgets('thème sombre : fond sombre, aucune exception', (tester) async {
    await _pump(tester, repo: _Repo(), mode: ThemeMode.dark);
    final bg = Theme.of(tester.element(find.byKey(const Key('area-title'))))
        .scaffoldBackgroundColor;
    expect(bg.computeLuminance(), lessThan(0.2));
    expect(find.text('Commerce 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
