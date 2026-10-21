// État de la recherche : anti-rebond 400 ms, chargement / vide / erreur / résultats, pagination infinie
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/di/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../onboarding/application/city_controller.dart';
import '../data/models/search_query.dart';
import '../data/models/search_result.dart';
import '../data/repositories/search_repository.dart';
import '../data/repositories/search_repository_api.dart';
import '../data/repositories/search_repository_fake.dart';

/// Attente après la dernière frappe avant de lancer la recherche.
const Duration kSearchDebounce = Duration(milliseconds: 400);

/// Dépôt de recherche : factice si `USE_FAKE_API=true`, sinon relié à l'API.
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  if (Env.useFakeApi) return SearchRepositoryFake();
  return SearchRepositoryApi(ref.read(dioProvider));
});

enum SearchStatus {
  /// Rien n'est encore lancé (ville pas encore connue).
  idle,
  loading,
  results,
  empty,
  error,
}

class SearchState {
  const SearchState({
    this.query = const SearchQuery(),
    this.status = SearchStatus.idle,
    this.items = const [],
    this.count = 0,
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.error,
    this.fromVoice = false,
    this.cleanedQuery,
  });

  final SearchQuery query;
  final SearchStatus status;
  final List<SearchResult> items;
  final int count;

  /// Dernière page chargée (0 = aucune).
  final int page;
  final bool hasMore;

  /// Vrai pendant le chargement d'une page suivante (les résultats déjà là restent).
  final bool loadingMore;

  /// La page suivante a échoué : les résultats restent, on peut réessayer.
  final bool loadMoreFailed;
  final ApiException? error;

  /// La recherche vient de la voix (POST voice) ; [query].q est alors la phrase reconnue.
  final bool fromVoice;

  /// Terme nettoyé renvoyé par le serveur pour une recherche vocale.
  final String? cleanedQuery;

  SearchState copyWith({
    SearchQuery? query,
    SearchStatus? status,
    List<SearchResult>? items,
    int? count,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
    ApiException? error,
    bool clearError = false,
    bool? fromVoice,
    String? cleanedQuery,
  }) =>
      SearchState(
        query: query ?? this.query,
        status: status ?? this.status,
        items: items ?? this.items,
        count: count ?? this.count,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
        error: clearError ? null : (error ?? this.error),
        fromVoice: fromVoice ?? this.fromVoice,
        cleanedQuery: cleanedQuery ?? this.cleanedQuery,
      );
}

/// Recherche de l'Accueil. Au démarrage : les commerces de la ville choisie (`q` vide).
final searchControllerProvider =
    NotifierProvider<SearchController, SearchState>(SearchController.new);

class SearchController extends Notifier<SearchState> {
  Timer? _timer;
  int _ticket = 0;

  @override
  SearchState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _ticket++;
    });
    final city = ref.watch(selectedCityProvider);
    if (city.isLoading) return const SearchState();
    final query = SearchQuery(zone: city.value?.id);
    Future.microtask(() {
      if (ref.mounted && state.status == SearchStatus.idle) _run(query);
    });
    return SearchState(query: query);
  }

  SearchRepository get _repo => ref.read(searchRepositoryProvider);

  /// Frappe en cours : relance après [kSearchDebounce] sans nouvelle frappe.
  void onTextChanged(String text) {
    _timer?.cancel();
    final next = state.query.copyWith(q: text);
    if (!state.fromVoice && next == state.query && state.status != SearchStatus.idle) return;
    _timer = Timer(kSearchDebounce, () => _run(next));
  }

  /// Validation du clavier, suggestion choisie : tout de suite, sans attendre.
  void submit(String text) {
    _timer?.cancel();
    _run(state.query.copyWith(q: text));
  }

  /// Change la zone (ville, quartier…) ; `null` = toutes les zones.
  void setZone(int? zone) {
    _timer?.cancel();
    _run(zone == null
        ? state.query.copyWith(clearZone: true)
        : state.query.copyWith(zone: zone));
  }

  /// Change le secteur (code stable) ; `null` = tous.
  void setSector(String? sector) {
    _timer?.cancel();
    _run(sector == null
        ? state.query.copyWith(clearSector: true)
        : state.query.copyWith(sector: sector));
  }

  /// Texte vocal reconnu : POST /api/search/voice/ avec la zone et le secteur en cours.
  void searchByVoice(String spoken) {
    _timer?.cancel();
    _run(state.query.copyWith(q: spoken.trim()), voice: true);
  }

  /// « Réessayer » après une erreur : relance la même recherche.
  void retry() {
    _timer?.cancel();
    _run(state.query, voice: state.fromVoice);
  }

  Future<void> _run(SearchQuery query, {bool voice = false}) async {
    final ticket = ++_ticket;
    state = SearchState(
      query: query,
      status: SearchStatus.loading,
      fromVoice: voice,
    );
    try {
      final page = await _fetch(query, voice, 1);
      if (!ref.mounted || ticket != _ticket) return;
      state = SearchState(
        query: query,
        status: page.results.isEmpty ? SearchStatus.empty : SearchStatus.results,
        items: page.results,
        count: page.count,
        page: 1,
        hasMore: page.hasNext && page.results.isNotEmpty,
        fromVoice: voice,
        cleanedQuery: page.cleanedQuery,
      );
    } on ApiException catch (e) {
      if (!ref.mounted || ticket != _ticket) return;
      state = SearchState(query: query, status: SearchStatus.error, error: e, fromVoice: voice);
    }
  }

  Future<SearchPage> _fetch(SearchQuery query, bool voice, int page) => voice
      ? _repo.voiceSearch(query.q, zone: query.zone, sector: query.sector, page: page)
      : _repo.search(query, page: page);

  /// Page suivante (liste qui arrive en bas). Sans effet s'il n'y en a pas ou si une charge est en cours.
  Future<void> loadMore() async {
    final s = state;
    if (s.status != SearchStatus.results || !s.hasMore || s.loadingMore) return;
    final ticket = _ticket;
    state = s.copyWith(loadingMore: true, loadMoreFailed: false);
    try {
      final page = await _fetch(s.query, s.fromVoice, s.page + 1);
      if (!ref.mounted || ticket != _ticket) return;
      final known = {for (final r in s.items) r.id};
      state = state.copyWith(
        items: [...s.items, for (final r in page.results) if (!known.contains(r.id)) r],
        count: page.count,
        page: s.page + 1,
        hasMore: page.hasNext && page.results.isNotEmpty,
        loadingMore: false,
      );
    } on ApiException {
      if (!ref.mounted || ticket != _ticket) return;
      state = state.copyWith(loadingMore: false, loadMoreFailed: true);
    }
  }
}
