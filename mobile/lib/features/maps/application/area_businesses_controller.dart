// État de l'écran Quartier : commerces d'un quartier, pagination infinie.
// Même format que la recherche ; aucun numéro (il ne sort que de POST /api/calls/initiate/).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../search/application/offline_controller.dart';
import '../../search/data/models/search_result.dart';
import 'map_controller.dart';

enum AreaStatus { loading, ready, empty, error }

class AreaBusinessesState {
  const AreaBusinessesState({
    this.status = AreaStatus.loading,
    this.items = const [],
    this.page = 1,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final AreaStatus status;
  final List<SearchResult> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;

  AreaBusinessesState copyWith({
    AreaStatus? status,
    List<SearchResult>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) =>
      AreaBusinessesState(
        status: status ?? this.status,
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

final areaBusinessesProvider = NotifierProvider.autoDispose
    .family<AreaBusinessesController, AreaBusinessesState, int>(
        AreaBusinessesController.new);

class AreaBusinessesController extends Notifier<AreaBusinessesState> {
  AreaBusinessesController(this.areaId);

  final int areaId;
  int _ticket = 0;

  @override
  AreaBusinessesState build() {
    ref.onDispose(() => _ticket++);
    Future.microtask(() {
      if (ref.mounted && state.status == AreaStatus.loading) _load();
    });
    return const AreaBusinessesState();
  }

  void _markOffline(ApiException e) {
    if (e.code == ApiErrorCode.network) {
      ref.read(offlineProvider.notifier).set(true);
    }
  }

  /// « Réessayer » après une erreur de la première page.
  Future<void> retry() {
    state = const AreaBusinessesState();
    return _load();
  }

  Future<void> _load() async {
    final ticket = ++_ticket;
    try {
      final page =
          await ref.read(mapRepositoryProvider).areaBusinesses(areaId, page: 1);
      if (!ref.mounted || ticket != _ticket) return;
      ref.read(offlineProvider.notifier).set(false);
      state = AreaBusinessesState(
        status: page.results.isEmpty ? AreaStatus.empty : AreaStatus.ready,
        items: page.results,
        hasMore: page.hasNext && page.results.isNotEmpty,
      );
    } on ApiException catch (e) {
      if (!ref.mounted || ticket != _ticket) return;
      _markOffline(e);
      state = const AreaBusinessesState(status: AreaStatus.error);
    }
  }

  /// Page suivante ; sans effet s'il n'y en a pas ou si une charge est en cours.
  Future<void> loadMore() async {
    final s = state;
    if (s.status != AreaStatus.ready || !s.hasMore || s.loadingMore) return;
    final ticket = _ticket;
    state = s.copyWith(loadingMore: true, loadMoreFailed: false);
    try {
      final page = await ref
          .read(mapRepositoryProvider)
          .areaBusinesses(areaId, page: s.page + 1);
      if (!ref.mounted || ticket != _ticket) return;
      final known = {for (final r in s.items) r.id};
      state = state.copyWith(
        items: [
          ...s.items,
          for (final r in page.results)
            if (!known.contains(r.id)) r
        ],
        page: s.page + 1,
        hasMore: page.hasNext && page.results.isNotEmpty,
        loadingMore: false,
      );
    } on ApiException catch (e) {
      if (!ref.mounted || ticket != _ticket) return;
      _markOffline(e);
      state = state.copyWith(loadingMore: false, loadMoreFailed: true);
    }
  }
}
