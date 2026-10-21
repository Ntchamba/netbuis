import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/storage/prefs.dart';
import 'package:netbuis/features/search/data/search_cache.dart';
import 'package:netbuis/features/auth/application/auth_controller.dart';
import 'package:netbuis/features/auth/application/auth_state.dart';
import 'package:netbuis/features/search/application/search_controller.dart';
import 'package:netbuis/features/search/application/suggestions_controller.dart';
import 'package:netbuis/features/search/data/models/search_query.dart';
import 'package:netbuis/features/search/data/models/search_result.dart';
import 'package:netbuis/features/search/data/models/suggestion.dart';
import 'package:netbuis/features/search/data/repositories/search_repository.dart';
import 'package:netbuis/features/search/data/repositories/search_repository_fake.dart';

import '../auth/login_test_helpers.dart' show MemoryPrefs;

/// Dépôt scénarisé : enregistre les appels, peut échouer ou répondre plus tard.
class ScriptedSearch implements SearchRepository {
  ScriptedSearch(this.inner);

  final SearchRepositoryFake inner;
  final List<String> calls = [];
  bool failSearch = false;
  bool failPage2 = false;
  bool failSuggestions = false;

  @override
  Future<SearchPage> search(SearchQuery query, {int page = 1}) async {
    calls.add('search:${query.q}:${query.zone}:${query.sector}:$page');
    if (failSearch || (failPage2 && page == 2)) {
      throw const ApiException(ApiErrorCode.network);
    }
    return inner.search(query, page: page);
  }

  @override
  Future<List<Suggestion>> suggestions(String q) async {
    calls.add('sugg:$q');
    if (failSuggestions) throw const ApiException(ApiErrorCode.network);
    return inner.suggestions(q);
  }

  @override
  Future<SearchPage> voiceSearch(String text, {int? zone, String? sector, int page = 1}) async {
    calls.add('voice:$text:$zone:$sector:$page');
    return inner.voiceSearch(text, zone: zone, sector: sector, page: page);
  }
}

/// Session ouverte sans toucher au stockage sécurisé.
class _StubAuth extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated();
}

ProviderContainer _container(ScriptedSearch repo, {SelectedCity? city}) {
  final c = ProviderContainer(overrides: [
    searchRepositoryProvider.overrideWithValue(repo),
    searchCacheProvider.overrideWithValue(MemorySearchCache()),
    authControllerProvider.overrideWith(_StubAuth.new),
    appPrefsProvider.overrideWithValue(
        MemoryPrefs(city: city ?? const SelectedCity(id: 16, name: 'Maroua'))),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test('au démarrage : commerces de la ville choisie (q vide, zone de la ville)', () async {
    final repo = ScriptedSearch(SearchRepositoryFake());
    final c = _container(repo);
    c.listen(searchControllerProvider, (_, __) {});
    await _settle();
    final s = c.read(searchControllerProvider);
    expect(s.status, SearchStatus.results);
    expect(s.items, hasLength(5));
    expect(repo.calls, ['search::16:null:1']);
  });

  test('anti-rebond : trois frappes rapprochées -> une seule recherche, après 400 ms', () async {
    final repo = ScriptedSearch(SearchRepositoryFake());
    final c = _container(repo);
    c.listen(searchControllerProvider, (_, __) {});
    await _settle();
    repo.calls.clear();
    final ctrl = c.read(searchControllerProvider.notifier);
    ctrl.onTextChanged('r');
    ctrl.onTextChanged('ri');
    ctrl.onTextChanged('riz');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(repo.calls, isEmpty, reason: 'pas encore 400 ms');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(repo.calls, ['search:riz:16:null:1']);
    expect(c.read(searchControllerProvider).items.map((r) => r.id), [1, 2]);
  });

  test('chargement puis vide : « zzzz » ne trouve rien', () async {
    final repo = ScriptedSearch(SearchRepositoryFake());
    final c = _container(repo);
    final states = <SearchStatus>[];
    c.listen(searchControllerProvider, (_, n) => states.add(n.status), fireImmediately: false);
    await _settle();
    states.clear();
    c.read(searchControllerProvider.notifier).submit('zzzz');
    await _settle();
    expect(states, [SearchStatus.loading, SearchStatus.empty]);
  });

  test('erreur puis réessayer', () async {
    final repo = ScriptedSearch(SearchRepositoryFake())..failSearch = true;
    final c = _container(repo);
    c.listen(searchControllerProvider, (_, __) {});
    await _settle();
    var s = c.read(searchControllerProvider);
    expect(s.status, SearchStatus.error);
    expect(s.error?.code, ApiErrorCode.network);
    repo.failSearch = false;
    c.read(searchControllerProvider.notifier).retry();
    await _settle();
    s = c.read(searchControllerProvider);
    expect(s.status, SearchStatus.results);
    expect(s.error, isNull);
  });

  test('une réponse en retard d\'une ancienne recherche est ignorée', () async {
    final repo = ScriptedSearch(SearchRepositoryFake());
    final c = _container(repo);
    c.listen(searchControllerProvider, (_, __) {});
    await _settle();
    final ctrl = c.read(searchControllerProvider.notifier);
    ctrl.submit('riz');
    ctrl.submit('pharmacie');
    await _settle();
    final s = c.read(searchControllerProvider);
    expect(s.query.q, 'pharmacie');
    expect(s.items.map((r) => r.id), [3]);
  });

  test('pagination infinie : pages ajoutées, fin quand il n\'y a plus de suivante', () async {
    final repo = ScriptedSearch(SearchRepositoryFake(pageSize: 2));
    final c = _container(repo);
    c.listen(searchControllerProvider, (_, __) {});
    await _settle();
    final ctrl = c.read(searchControllerProvider.notifier);
    expect(c.read(searchControllerProvider).items, hasLength(2));
    expect(c.read(searchControllerProvider).hasMore, isTrue);
    await ctrl.loadMore();
    await ctrl.loadMore();
    final s = c.read(searchControllerProvider);
    expect(s.items.map((r) => r.id), [1, 2, 3, 4, 5]);
    expect(s.hasMore, isFalse);
    final before = repo.calls.length;
    await ctrl.loadMore();
    expect(repo.calls.length, before, reason: 'plus de page : aucun appel');
  });

  test('pagination : échec de la page 2 garde les résultats et permet de réessayer', () async {
    final repo = ScriptedSearch(SearchRepositoryFake(pageSize: 2))..failPage2 = true;
    final c = _container(repo);
    c.listen(searchControllerProvider, (_, __) {});
    await _settle();
    final ctrl = c.read(searchControllerProvider.notifier);
    await ctrl.loadMore();
    var s = c.read(searchControllerProvider);
    expect(s.status, SearchStatus.results);
    expect(s.items, hasLength(2));
    expect(s.loadMoreFailed, isTrue);
    repo.failPage2 = false;
    await ctrl.loadMore();
    s = c.read(searchControllerProvider);
    expect(s.items, hasLength(4));
    expect(s.loadMoreFailed, isFalse);
  });

  test('filtres : zone et secteur relancent la recherche', () async {
    final repo = ScriptedSearch(SearchRepositoryFake());
    final c = _container(repo);
    c.listen(searchControllerProvider, (_, __) {});
    await _settle();
    final ctrl = c.read(searchControllerProvider.notifier);
    ctrl.setSector('alimentation');
    await _settle();
    expect(c.read(searchControllerProvider).items.map((r) => r.id), [1, 2, 5]);
    ctrl.setZone(17);
    await _settle();
    expect(c.read(searchControllerProvider).items.map((r) => r.id), [1]);
    ctrl.setZone(null);
    ctrl.setSector(null);
    await _settle();
    expect(c.read(searchControllerProvider).items, hasLength(5));
  });

  test('recherche vocale : POST voice, puis pages suivantes par voice', () async {
    final repo = ScriptedSearch(SearchRepositoryFake(pageSize: 1));
    final c = _container(repo);
    c.listen(searchControllerProvider, (_, __) {});
    await _settle();
    repo.calls.clear();
    final ctrl = c.read(searchControllerProvider.notifier);
    ctrl.searchByVoice('je cherche du riz à Maroua');
    await _settle();
    var s = c.read(searchControllerProvider);
    expect(s.fromVoice, isTrue);
    expect(s.cleanedQuery, 'riz');
    expect(s.items.map((r) => r.id), [1]);
    await ctrl.loadMore();
    s = c.read(searchControllerProvider);
    expect(s.items.map((r) => r.id), [1, 2]);
    expect(repo.calls, [
      'voice:je cherche du riz à Maroua:16:null:1',
      'voice:je cherche du riz à Maroua:16:null:2',
    ]);
  });

  test('suggestions : anti-rebond, 2 caractères au moins, 8 au plus', () async {
    final repo = ScriptedSearch(SearchRepositoryFake());
    final c = _container(repo);
    c.listen(suggestionsControllerProvider, (_, __) {});
    final ctrl = c.read(suggestionsControllerProvider.notifier);
    ctrl.onTextChanged('r');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(repo.calls, isEmpty);
    ctrl.onTextChanged('ri');
    ctrl.onTextChanged('riz');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(repo.calls, ['sugg:riz']);
    expect(c.read(suggestionsControllerProvider).map((s) => s.text), ['riz', 'riz local']);
    ctrl.onTextChanged('');
    expect(c.read(suggestionsControllerProvider), isEmpty);
  });

  test('suggestions : une erreur réseau vide la liste sans planter', () async {
    final repo = ScriptedSearch(SearchRepositoryFake())..failSuggestions = true;
    final c = _container(repo);
    c.listen(suggestionsControllerProvider, (_, __) {});
    c.read(suggestionsControllerProvider.notifier).onTextChanged('riz');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(c.read(suggestionsControllerProvider), isEmpty);
  });
}
