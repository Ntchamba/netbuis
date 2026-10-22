// État du fil du forum : chargement / vide / erreur / publications, pagination infinie,
// tirer pour rafraîchir, dernier fil gardé pour le hors connexion.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../onboarding/application/city_controller.dart';
import '../../search/application/offline_controller.dart';
import '../data/forum_feed_cache.dart';
import '../data/models/feed_post.dart';
import 'forum_services.dart';

enum FeedStatus { idle, loading, results, empty, error }

class FeedState {
  const FeedState({
    this.zone,
    this.status = FeedStatus.idle,
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.error,
    this.fromCache = false,
  });

  /// Zone (ville) du fil ; null = toutes les zones.
  final int? zone;
  final FeedStatus status;
  final List<FeedPost> items;

  /// Dernière page chargée (0 = aucune).
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;
  final ApiException? error;

  /// Vrai : ce sont les derniers fils mémorisés, affichés faute de réseau.
  final bool fromCache;

  FeedState copyWith({
    FeedStatus? status,
    List<FeedPost>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) =>
      FeedState(
        zone: zone,
        status: status ?? this.status,
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
        error: error,
        fromCache: fromCache,
      );
}

/// Fil des publications de la ville choisie.
final forumFeedProvider =
    NotifierProvider<ForumFeedController, FeedState>(ForumFeedController.new);

class ForumFeedController extends Notifier<FeedState> {
  int _ticket = 0;

  @override
  FeedState build() {
    ref.onDispose(() => _ticket++);
    // Déconnexion : le dernier fil mémorisé est effacé.
    ref.listen(authControllerProvider, (_, next) {
      if (next is AuthLoggedOut) {
        _cacheSafely(() => ref.read(forumFeedCacheProvider).clear());
      }
    });
    final city = ref.watch(selectedCityProvider);
    if (city.isLoading) return const FeedState();
    final zone = city.value?.id;
    Future.microtask(() {
      if (ref.mounted && state.status == FeedStatus.idle) _run(zone);
    });
    return FeedState(zone: zone);
  }

  /// La mémoire du téléphone ne doit jamais casser le fil.
  static void _cacheSafely(Future<void> Function() action) {
    action().catchError((Object _) {});
  }

  /// Un commentaire vient d'être publié depuis la page d'une publication : le fil affiche le bon nombre.
  void setCommentsCount(int postId, int count) {
    if (state.items.every((p) => p.id != postId || p.commentsCount == count)) {
      return;
    }
    state = state.copyWith(items: [
      for (final p in state.items)
        p.id == postId ? p.copyWith(commentsCount: count) : p,
    ]);
  }

  /// « Réessayer » après une erreur.
  Future<void> retry() => _run(state.zone);

  /// Tirer pour rafraîchir : les publications déjà là restent visibles pendant le chargement.
  /// Renvoie faux si le rafraîchissement a échoué (le fil affiché reste inchangé).
  Future<bool> refresh() async {
    if (state.status != FeedStatus.results &&
        state.status != FeedStatus.empty) {
      await _run(state.zone);
      return state.status != FeedStatus.error;
    }
    final ticket = ++_ticket;
    final zone = state.zone;
    try {
      final page =
          await ref.read(forumFeedRepositoryProvider).feed(zone: zone, page: 1);
      if (!ref.mounted || ticket != _ticket) return true;
      _applyFirstPage(zone, page);
      return true;
    } on ApiException catch (e) {
      if (!ref.mounted || ticket != _ticket) return false;
      if (e.code == ApiErrorCode.network) {
        ref.read(offlineProvider.notifier).set(true);
      }
      return false;
    }
  }

  void _applyFirstPage(int? zone, ForumPage<FeedPost> page) {
    ref.read(offlineProvider.notifier).set(false);
    // La mémoire n'est écrite qu'après un succès, jamais après une erreur.
    if (page.items.isNotEmpty) {
      _cacheSafely(() => ref
          .read(forumFeedCacheProvider)
          .write(CachedFeed(zone: zone, items: page.items, count: page.count)));
    }
    state = FeedState(
      zone: zone,
      status: page.items.isEmpty ? FeedStatus.empty : FeedStatus.results,
      items: page.items,
      page: 1,
      hasMore: page.hasNext && page.items.isNotEmpty,
    );
  }

  Future<void> _run(int? zone) async {
    final ticket = ++_ticket;
    state = FeedState(zone: zone, status: FeedStatus.loading);
    try {
      final page =
          await ref.read(forumFeedRepositoryProvider).feed(zone: zone, page: 1);
      if (!ref.mounted || ticket != _ticket) return;
      _applyFirstPage(zone, page);
    } on ApiException catch (e) {
      if (!ref.mounted || ticket != _ticket) return;
      if (e.code == ApiErrorCode.network) {
        ref.read(offlineProvider.notifier).set(true);
        final saved = await _readCache();
        if (!ref.mounted || ticket != _ticket) return;
        if (saved != null && saved.zone == zone && saved.items.isNotEmpty) {
          state = FeedState(
            zone: zone,
            status: FeedStatus.results,
            items: saved.items,
            page: 1,
            fromCache: true,
          );
          return;
        }
      }
      state = FeedState(zone: zone, status: FeedStatus.error, error: e);
    }
  }

  Future<CachedFeed?> _readCache() async {
    try {
      return await ref.read(forumFeedCacheProvider).read();
    } on Object {
      return null;
    }
  }

  /// Page suivante (la liste arrive en bas). Sans effet s'il n'y en a pas ou si une charge est en cours.
  Future<void> loadMore() async {
    final s = state;
    if (s.status != FeedStatus.results ||
        !s.hasMore ||
        s.loadingMore ||
        s.fromCache) {
      return;
    }
    final ticket = _ticket;
    state = s.copyWith(loadingMore: true, loadMoreFailed: false);
    try {
      final page = await ref
          .read(forumFeedRepositoryProvider)
          .feed(zone: s.zone, page: s.page + 1);
      if (!ref.mounted || ticket != _ticket) return;
      final known = {for (final p in s.items) p.id};
      state = state.copyWith(
        items: [
          ...s.items,
          for (final p in page.items)
            if (!known.contains(p.id)) p
        ],
        page: s.page + 1,
        hasMore: page.hasNext && page.items.isNotEmpty,
        loadingMore: false,
      );
    } on ApiException catch (e) {
      if (!ref.mounted || ticket != _ticket) return;
      if (e.code == ApiErrorCode.network) {
        ref.read(offlineProvider.notifier).set(true);
      }
      state = state.copyWith(loadingMore: false, loadMoreFailed: true);
    }
  }
}
