// État de l'historique : chargement / vide / erreur / liste, pagination infinie.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/di/providers.dart';
import '../../../core/network/api_exception.dart';
import '../data/models/call_history_entry.dart';
import '../data/repositories/call_history_repository.dart';
import '../data/repositories/call_history_repository_api.dart';
import '../data/repositories/call_history_repository_fake.dart';

final callHistoryRepositoryProvider = Provider<CallHistoryRepository>((ref) {
  if (Env.useFakeApi) return CallHistoryRepositoryFake();
  return CallHistoryRepositoryApi(ref.read(dioProvider));
});

/// Heure actuelle (remplaçable dans les tests) pour « Aujourd'hui » / « Hier ».
final historyNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

enum HistoryStatus { loading, results, empty, error }

class HistoryState {
  const HistoryState({
    this.status = HistoryStatus.loading,
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.error,
  });

  final HistoryStatus status;
  final List<CallHistoryEntry> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;
  final ApiException? error;

  HistoryState copyWith({
    HistoryStatus? status,
    List<CallHistoryEntry>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) =>
      HistoryState(
        status: status ?? this.status,
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
        error: error,
      );
}

/// Rechargé à chaque ouverture de l'écran (autoDispose).
final callHistoryControllerProvider =
    NotifierProvider.autoDispose<CallHistoryController, HistoryState>(
        CallHistoryController.new);

class CallHistoryController extends Notifier<HistoryState> {
  int _ticket = 0;

  @override
  HistoryState build() {
    ref.onDispose(() => _ticket++);
    Future.microtask(() {
      if (ref.mounted &&
          state.page == 0 &&
          state.status == HistoryStatus.loading) {
        _first();
      }
    });
    return const HistoryState();
  }

  CallHistoryRepository get _repo => ref.read(callHistoryRepositoryProvider);

  /// « Réessayer » après une erreur de la première page.
  Future<void> retry() {
    state = const HistoryState();
    return _first();
  }

  Future<void> _first() async {
    final ticket = ++_ticket;
    try {
      final page = await _repo.history(page: 1);
      if (!ref.mounted || ticket != _ticket) return;
      state = HistoryState(
        status:
            page.results.isEmpty ? HistoryStatus.empty : HistoryStatus.results,
        items: page.results,
        page: 1,
        hasMore: page.hasNext && page.results.isNotEmpty,
      );
    } on ApiException catch (e) {
      if (!ref.mounted || ticket != _ticket) return;
      state = HistoryState(status: HistoryStatus.error, error: e);
    }
  }

  /// Page suivante ; sans effet s'il n'y en a pas ou si une charge est en cours.
  Future<void> loadMore() async {
    final s = state;
    if (s.status != HistoryStatus.results || !s.hasMore || s.loadingMore) {
      return;
    }
    final ticket = _ticket;
    state = s.copyWith(loadingMore: true, loadMoreFailed: false);
    try {
      final page = await _repo.history(page: s.page + 1);
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
    } on ApiException {
      if (!ref.mounted || ticket != _ticket) return;
      state = state.copyWith(loadingMore: false, loadMoreFailed: true);
    }
  }
}
