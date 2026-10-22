// Page d'une publication : la publication, ses commentaires paginés, l'envoi d'un commentaire
// (affiché tout de suite, retiré si le serveur refuse).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../account/application/account_controller.dart';
import '../../search/application/offline_controller.dart';
import '../data/models/feed_post.dart';
import '../data/repositories/forum_feed_repository.dart';
import 'forum_feed_controller.dart';
import 'forum_services.dart';
import 'report_controller.dart';

enum ThreadStatus { loading, ready, error }

class ThreadState {
  const ThreadState({
    this.status = ThreadStatus.loading,
    this.post,
    this.comments = const [],
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.sending = false,
    this.error,
  });

  final ThreadStatus status;
  final FeedPost? post;
  final List<ForumComment> comments;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;

  /// Un commentaire est en cours d'envoi : le champ et le bouton sont désactivés.
  final bool sending;
  final ApiException? error;

  ThreadState copyWith({
    ThreadStatus? status,
    FeedPost? post,
    List<ForumComment>? comments,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
    bool? sending,
  }) =>
      ThreadState(
        status: status ?? this.status,
        post: post ?? this.post,
        comments: comments ?? this.comments,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
        sending: sending ?? this.sending,
        error: error,
      );
}

final postThreadProvider = NotifierProvider.autoDispose
    .family<PostThreadController, ThreadState, int>(PostThreadController.new);

class PostThreadController extends Notifier<ThreadState> {
  PostThreadController(this.postId);

  final int postId;
  int _ticket = 0;
  int _pendingId = 0;

  @override
  ThreadState build() {
    ref.onDispose(() => _ticket++);
    // Un commentaire que je viens de signaler disparaît tout de suite de la page.
    ref.listen(reportsProvider.select((r) => r.comments), (_, hidden) {
      final kept = _visible(state.comments);
      if (kept.length != state.comments.length) {
        state = state.copyWith(comments: kept);
      }
    });
    Future.microtask(() {
      if (ref.mounted &&
          state.status == ThreadStatus.loading &&
          state.page == 0) {
        _load();
      }
    });
    return const ThreadState();
  }

  List<ForumComment> _visible(List<ForumComment> items) {
    final hidden = ref.read(reportsProvider).comments;
    return hidden.isEmpty
        ? items
        : [
            for (final c in items)
              if (!hidden.contains(c.id)) c
          ];
  }

  ForumFeedRepository get _repo => ref.read(forumFeedRepositoryProvider);

  /// « Réessayer » après une erreur.
  Future<void> retry() {
    state = const ThreadState();
    return _load();
  }

  Future<void> _load() async {
    final ticket = ++_ticket;
    try {
      final results = await Future.wait<Object>(
          [_repo.getPost(postId), _repo.comments(postId)]);
      if (!ref.mounted || ticket != _ticket) return;
      ref.read(offlineProvider.notifier).set(false);
      final post = results[0] as FeedPost;
      final page = results[1] as ForumPage<ForumComment>;
      state = ThreadState(
        status: ThreadStatus.ready,
        post: post,
        comments: _visible(page.items),
        page: 1,
        hasMore: page.hasNext && page.items.isNotEmpty,
      );
    } on ApiException catch (e) {
      if (!ref.mounted || ticket != _ticket) return;
      if (e.code == ApiErrorCode.network) {
        ref.read(offlineProvider.notifier).set(true);
      }
      state = ThreadState(status: ThreadStatus.error, error: e);
    }
  }

  /// Page suivante des commentaires (fin de liste). Sans effet s'il n'y en a pas ou si une charge est en cours.
  Future<void> loadMore() async {
    final s = state;
    if (s.status != ThreadStatus.ready || !s.hasMore || s.loadingMore) return;
    final ticket = _ticket;
    state = s.copyWith(loadingMore: true, loadMoreFailed: false);
    try {
      final page = await _repo.comments(postId, page: s.page + 1);
      if (!ref.mounted || ticket != _ticket) return;
      final merged = [...state.comments];
      final known = {for (final c in merged) c.id};
      for (final c in _visible(page.items)) {
        if (known.add(c.id)) merged.add(c);
      }
      // Un commentaire que je viens d'écrire peut précéder des pages pas encore chargées.
      final pending = [
        for (final c in merged)
          if (c.pending) c
      ];
      final confirmed = [
        for (final c in merged)
          if (!c.pending) c
      ]..sort((a, b) {
          final byDate = a.createdAt.compareTo(b.createdAt);
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });
      state = state.copyWith(
        comments: [...confirmed, ...pending],
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

  /// Envoie un commentaire : il apparaît tout de suite, puis est remplacé par la réponse du serveur.
  /// Si le serveur refuse (429, 403, réseau…), il est retiré et l'erreur est relancée
  /// ([ApiException]) pour que l'écran affiche le message. Sans effet pendant un envoi.
  Future<void> addComment(String rawText,
      {required String fallbackName}) async {
    final text = rawText.trim();
    final s = state;
    if (text.isEmpty || s.status != ThreadStatus.ready || s.sending) return;
    final name = _myName(fallbackName);
    final temp = ForumComment(
      id: -(++_pendingId),
      authorName: name,
      initials: initialsOf(name),
      text: text,
      createdAt: DateTime.now(),
      isMine: true,
      pending: true,
    );
    state = s.copyWith(comments: [...s.comments, temp], sending: true);
    try {
      final saved = await _repo.addComment(postId, text);
      if (!ref.mounted) return;
      ref.read(offlineProvider.notifier).set(false);
      final current = state;
      final kept = [
        for (final c in current.comments)
          if (c.id != temp.id && c.id != saved.id) c
      ];
      final post = current.post;
      final count = (post?.commentsCount ?? 0) + 1;
      state = current.copyWith(
        comments: [...kept, saved],
        post: post?.copyWith(commentsCount: count),
        sending: false,
      );
      ref.read(forumFeedProvider.notifier).setCommentsCount(postId, count);
    } on ApiException catch (e) {
      if (ref.mounted) {
        if (e.code == ApiErrorCode.network) {
          ref.read(offlineProvider.notifier).set(true);
        }
        state = state.copyWith(
          comments: [
            for (final c in state.comments)
              if (c.id != temp.id) c
          ],
          sending: false,
        );
      }
      rethrow;
    }
  }

  String _myName(String fallback) {
    // Le profil n'est lu que s'il est déjà chargé : aucune requête de plus pour un commentaire.
    final name = ref.exists(accountControllerProvider)
        ? (ref.read(accountControllerProvider).value?.name.trim() ?? '')
        : '';
    return name.isEmpty ? fallback : name;
  }
}
