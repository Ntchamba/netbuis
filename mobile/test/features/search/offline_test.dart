// T055 : dernier résultat hors connexion, appels et WhatsApp désactivés sans réseau.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:netbuis/features/trends/application/trends_controller.dart';
import '../home/no_trends.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/data/referentials/referential_repository_fake.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/storage/prefs.dart';
import 'package:netbuis/features/auth/application/auth_controller.dart';
import 'package:netbuis/features/auth/application/auth_state.dart';
import 'package:netbuis/features/business/presentation/widgets/contact_actions.dart';
import 'package:netbuis/features/call/application/call_history_controller.dart';
import 'package:netbuis/features/call/data/models/call_history_entry.dart';
import 'package:netbuis/features/call/data/repositories/call_history_repository.dart';
import 'package:netbuis/features/call/presentation/screens/call_history_screen.dart';
import 'package:netbuis/features/call/presentation/widgets/call_button.dart';
import 'package:netbuis/features/home/presentation/screens/home_screen.dart';
import 'package:netbuis/features/search/application/offline_controller.dart';
import 'package:netbuis/features/search/application/search_controller.dart';
import 'package:netbuis/features/search/data/models/search_query.dart';
import 'package:netbuis/features/search/data/models/search_result.dart';
import 'package:netbuis/features/search/data/repositories/search_repository_fake.dart';
import 'package:netbuis/features/search/data/search_cache.dart';

import '../auth/login_test_helpers.dart' show MemoryPrefs;
import '../call/call_test_helpers.dart';

const _data = [
  SearchResult(
      id: 1, name: 'Boutique Aminatou', kind: 'produit', secteur: 'Alimentation',
      zone: ResultZone(id: 17, name: 'Hardé'), descriptionActivite: 'Riz et huile'),
  SearchResult(
      id: 2, name: 'Couturier Ibrahim', kind: 'service', secteur: 'Artisanat',
      zone: ResultZone(id: 18, name: 'Dougoï'), descriptionActivite: 'Sur mesure'),
];

class _Search extends SearchRepositoryFake {
  _Search() : super(data: _data);
  ApiException? error;

  @override
  Future<SearchPage> search(SearchQuery query, {int page = 1}) async {
    final e = error;
    if (e != null) throw e;
    return super.search(query, page: page);
  }
}

class _Off extends OfflineController {
  _Off(this.value);
  final bool value;
  @override
  bool build() => value;
}

class _Auth extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated();
  void out() => state = const AuthLoggedOut();
}

const _net = ApiException(ApiErrorCode.network);

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 100));

ProviderContainer _container(_Search repo, MemorySearchCache cache, {_Auth? auth}) {
  final c = ProviderContainer(overrides: [
    searchRepositoryProvider.overrideWithValue(repo),
    searchCacheProvider.overrideWithValue(cache),
    trendsRepositoryProvider.overrideWithValue(const NoTrendsRepository()),
    appPrefsProvider.overrideWithValue(MemoryPrefs(city: const SelectedCity(id: 16, name: 'Maroua'))),
    authControllerProvider.overrideWith(() => auth ?? _Auth()),
  ]);
  addTearDown(c.dispose);
  c.listen(searchControllerProvider, (_, __) {});
  return c;
}

void main() {
  group('mémoire du dernier résultat', () {
    test('écrite après un succès, avec requête, filtres et résultats', () async {
      final cache = MemorySearchCache();
      final c = _container(_Search(), cache);
      await _settle();
      expect(cache.writes, 1);
      final saved = (await cache.read())!;
      expect(saved.query, const SearchQuery(zone: 16));
      expect(saved.items.map((r) => r.name), ['Boutique Aminatou', 'Couturier Ibrahim']);
      expect(c.read(offlineProvider), isFalse);
    });

    test('jamais écrite après une erreur (et l\'ancienne reste intacte)', () async {
      final cache = MemorySearchCache();
      final repo = _Search();
      final c = _container(repo, cache);
      await _settle();
      final before = cache.raw;
      repo.error = _net;
      c.read(searchControllerProvider.notifier).submit('riz');
      await _settle();
      repo.error = const ApiException(ApiErrorCode.unknown);
      c.read(searchControllerProvider.notifier).submit('huile');
      await _settle();
      expect(cache.writes, 1);
      expect(cache.raw, before);
    });

    test('aucune écriture si la toute première recherche échoue', () async {
      final cache = MemorySearchCache();
      final repo = _Search()..error = _net;
      _container(repo, cache);
      await _settle();
      expect(cache.writes, 0);
      expect(cache.raw, isNull);
    });

    test('aucun numéro, lien wa.me ni jeton dans le contenu mémorisé', () async {
      final cache = MemorySearchCache();
      _container(_Search(), cache);
      await _settle();
      final raw = cache.raw!;
      for (final bad in ['wa.me', 'phone', 'telephone', 'token', 'access', 'refresh', '+237', 'http']) {
        expect(raw.toLowerCase().contains(bad), isFalse, reason: bad);
      }
      expect(RegExp(r'\d{8,}').hasMatch(raw), isFalse);
    });
  });

  group('lecture hors connexion', () {
    test('réseau coupé : les derniers résultats s\'affichent, marqués hors connexion', () async {
      final cache = MemorySearchCache();
      final repo = _Search();
      final c = _container(repo, cache);
      await _settle();
      repo.error = _net;
      c.read(searchControllerProvider.notifier).submit('riz');
      await _settle();
      final s = c.read(searchControllerProvider);
      expect(s.fromCache, isTrue);
      expect(s.status, SearchStatus.results);
      expect(s.items, hasLength(2));
      expect(s.hasMore, isFalse);
      expect(c.read(offlineProvider), isTrue);
    });

    test('retour du réseau : Réessayer relance la recherche voulue et enlève la mention', () async {
      final cache = MemorySearchCache();
      final repo = _Search();
      final c = _container(repo, cache);
      await _settle();
      repo.error = _net;
      c.read(searchControllerProvider.notifier).submit('riz');
      await _settle();
      repo.error = null;
      c.read(searchControllerProvider.notifier).retry();
      await _settle();
      final s = c.read(searchControllerProvider);
      expect(s.fromCache, isFalse);
      expect(s.query.q, 'riz');
      expect(c.read(offlineProvider), isFalse);
    });

    test('hors connexion sans mémoire : message d\'erreur habituel', () async {
      final c = _container(_Search()..error = _net, MemorySearchCache());
      await _settle();
      expect(c.read(searchControllerProvider).status, SearchStatus.error);
    });

    test('une erreur autre que le réseau n\'affiche pas la mémoire', () async {
      final cache = MemorySearchCache();
      final repo = _Search();
      final c = _container(repo, cache);
      await _settle();
      repo.error = const ApiException(ApiErrorCode.unknown);
      c.read(searchControllerProvider.notifier).submit('riz');
      await _settle();
      expect(c.read(searchControllerProvider).status, SearchStatus.error);
      expect(c.read(offlineProvider), isFalse);
    });

    test('déconnexion : la mémoire est effacée', () async {
      final cache = MemorySearchCache();
      final auth = _Auth();
      final c = _container(_Search(), cache, auth: auth);
      await _settle();
      expect(cache.raw, isNotNull);
      c.read(authControllerProvider);
      auth.out();
      await _settle();
      expect(cache.raw, isNull);
    });

    test('contenu illisible : ignoré', () async {
      final cache = MemorySearchCache()..raw = '{"v":99}';
      expect(await cache.read(), isNull);
    });
  });

  group('Accueil hors connexion', () {
    Future<void> pumpHome(WidgetTester tester, _Search repo, MemorySearchCache cache,
        {FakeCallRepository? calls}) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appPrefsProvider.overrideWithValue(MemoryPrefs()),
          searchRepositoryProvider.overrideWithValue(repo),
          searchCacheProvider.overrideWithValue(cache),
          trendsRepositoryProvider.overrideWithValue(const NoTrendsRepository()),
          authControllerProvider.overrideWith(_Auth.new),
          referentialRepositoryProvider.overrideWithValue(const ReferentialRepositoryFake()),
          ...callOverrides(FakeCallChannel(), calls ?? FakeCallRepository()),
        ],
        child: testApp(Scaffold(body: HomeScreen(onOpenSearch: () {}))),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('mention hors connexion, cartes lisibles, boutons désactivés avec message',
        (tester) async {
      final cache = MemorySearchCache();
      await cache.write(const CachedSearch(query: SearchQuery(zone: 16), items: _data, count: 2));
      await pumpHome(tester, _Search()..error = _net, cache);
      expect(find.byKey(const Key('offline-banner')), findsOneWidget);
      expect(find.textContaining('Hors connexion'), findsWidgets);
      expect(find.text('Boutique Aminatou'), findsOneWidget);
      expect(find.byKey(const Key('card-call-offline')), findsWidgets);
      final call = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Appeler').first);
      expect(call.onPressed, isNull);
      final wa = tester.widget<OutlinedButton>(find.byKey(const Key('card-whatsapp')).first.evaluate().isEmpty
          ? find.byType(OutlinedButton).first
          : find.descendant(
              of: find.byKey(const Key('card-whatsapp')), matching: find.byType(OutlinedButton)).first);
      expect(wa.onPressed, isNull);
    });

    testWidgets('Réessayer : le réseau revient, la mention disparaît et les boutons s\'activent',
        (tester) async {
      final cache = MemorySearchCache();
      await cache.write(const CachedSearch(query: SearchQuery(zone: 16), items: _data, count: 2));
      final repo = _Search()..error = _net;
      await pumpHome(tester, repo, cache);
      repo.error = null;
      await tester.tap(find.byKey(const Key('offline-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('offline-banner')), findsNothing);
      final call = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Appeler').first);
      expect(call.onPressed, isNotNull);
    });

    testWidgets('en ligne : pas de bandeau', (tester) async {
      await pumpHome(tester, _Search(), MemorySearchCache());
      expect(find.byKey(const Key('offline-banner')), findsNothing);
      expect(find.byKey(const Key('card-call-offline')), findsNothing);
    });
  });

  group('fiche et historique', () {
    testWidgets('fiche : Appeler et WhatsApp désactivés avec message', (tester) async {
      await tester.pumpWidget(testApp(const SingleChildScrollView(
        child: ContactActions(businessName: 'Chez Aminatou', whatsappAvailable: true,
            offline: true),
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-offline')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('detail-call'))
          .evaluate().isEmpty ? find.byType(FilledButton) : find.descendant(
              of: find.byKey(const Key('detail-call')), matching: find.byType(FilledButton))).onPressed,
          isNull);
      expect(find.textContaining('Hors connexion'), findsWidgets);
    });

    testWidgets('fiche en ligne : boutons actifs si l\'action est fournie', (tester) async {
      await tester.pumpWidget(testApp(SingleChildScrollView(
        child: ContactActions(businessName: 'Chez Aminatou', whatsappAvailable: true,
            onCall: () {}, onWhatsapp: () {}),
      )));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-offline')), findsNothing);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
    });

    testWidgets('historique : Rappeler et WhatsApp désactivés hors connexion', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...callOverrides(FakeCallChannel(), FakeCallRepository()),
          callHistoryRepositoryProvider.overrideWithValue(_History()),
        ],
        child: testApp(const CallHistoryScreen()),
      ));
      await tester.pumpAndSettle();
      // Le réseau tombe après le chargement de la liste.
      ProviderScope.containerOf(tester.element(find.byType(CallHistoryScreen)))
          .read(offlineProvider.notifier)
          .set(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-offline')), findsOneWidget);
      expect(tester.widget<IconButton>(find.byKey(const ValueKey('history-recall-1'))).onPressed,
          isNull);
      expect(tester.widget<IconButton>(find.byKey(const ValueKey('history-whatsapp-1'))).onPressed,
          isNull);
    });

    testWidgets('startCall hors connexion : message, aucune demande au serveur', (tester) async {
      final calls = FakeCallRepository();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          offlineProvider.overrideWith(() => _Off(true)),
          ...callOverrides(FakeCallChannel(), calls),
        ],
        child: testApp(Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => startCall(context, businessId: 1, businessName: 'X'),
              child: const Text('go'),
            ),
          ),
        )),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(find.textContaining('Pas de réseau'), findsOneWidget);
      expect(calls.requests, isEmpty);
    });
  });
}

class _History implements CallHistoryRepository {
  @override
  Future<CallHistoryPage> history({int page = 1}) async => CallHistoryPage(
        count: 1,
        hasNext: false,
        results: [
          CallHistoryEntry(
            id: 1,
            businessId: 5,
            businessName: 'Chez Aminatou',
            zone: 'Hardé',
            date: DateTime(2026, 10, 20, 9, 14),
            type: HistoryType.call,
          ),
        ],
      );
}
