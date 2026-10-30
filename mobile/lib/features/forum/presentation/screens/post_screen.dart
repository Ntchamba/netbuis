import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../search/application/offline_controller.dart';
import '../../application/comment_errors.dart';
import '../../application/post_thread_controller.dart';
import '../../application/post_time.dart';
import '../../data/models/feed_post.dart';
import '../../data/repositories/forum_feed_repository.dart';
import '../../data/models/report.dart';
import '../widgets/post_visuals.dart';
import '../widgets/report_menu_button.dart';
import '../widgets/report_sheet.dart';

/// Page d'une publication (maquette Publication) : le commerce, le média, la légende,
/// l'étiquette produit, les commentaires (suite chargée en bas de liste) et le champ pour écrire.
class PostScreen extends ConsumerStatefulWidget {
  const PostScreen({super.key, required this.postId});

  final int postId;

  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> {
  final _scroll = ScrollController();
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 300) {
        ref.read(postThreadProvider(widget.postId).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = _text.text.trim();
    final notifier = ref.read(postThreadProvider(widget.postId).notifier);
    if (text.isEmpty || ref.read(postThreadProvider(widget.postId)).sending) {
      return;
    }
    _text.clear();
    final future =
        notifier.addComment(text, fallbackName: l10n.t('forum.comment.me'));
    // Le commentaire vient d'être ajouté en bas de la liste : on y descend pour le montrer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
    try {
      await future;
    } on Object catch (e) {
      // Refusé : le commentaire a été retiré de la liste, le texte revient dans le champ.
      if (!mounted) return;
      if (_text.text.isEmpty) {
        _text.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.t(commentErrorKey(e)))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final state = ref.watch(postThreadProvider(widget.postId));
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 6),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.border))),
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('post-back'),
                onPressed: () => context.pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: c.textSecondary,
                ),
                icon: const Icon(Icons.chevron_left, size: 20),
                label: Text(l10n.t('forum.title'),
                    style: const TextStyle(fontSize: 13)),
              ),
            ),
            Expanded(child: _body(context, state)),
            if (state.status == ThreadStatus.ready) _composer(context, state),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ThreadState state) {
    final l10n = L10n.of(context);
    switch (state.status) {
      case ThreadStatus.loading:
        return Semantics(
          label: l10n.t('posts.loading'),
          liveRegion: true,
          child: const Center(child: CircularProgressIndicator()),
        );
      case ThreadStatus.error:
        final gone = state.error?.statusCode == 404;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(l10n.t(forumLoadErrorKey(state.error)),
                      key: const ValueKey('post-error'),
                      textAlign: TextAlign.center),
                ),
                if (!gone) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('post-retry'),
                    onPressed: () => ref
                        .read(postThreadProvider(widget.postId).notifier)
                        .retry(),
                    style:
                        TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    child: Text(l10n.t('profile.retry')),
                  ),
                ],
              ],
            ),
          ),
        );
      case ThreadStatus.ready:
        final post = state.post!;
        final comments = state.comments;
        final extra = state.loadingMore || state.loadMoreFailed ? 1 : 0;
        final now = DateTime.now();
        return ListView.builder(
          controller: _scroll,
          itemCount: 2 + (comments.isEmpty ? 1 : comments.length) + extra,
          itemBuilder: (context, i) {
            if (i == 0) {
              return _PostHeader(
                post: post,
                now: now,
                offline: ref.watch(offlineProvider),
                onReport: () => openReport(context,
                    target: ReportTarget.post,
                    id: post.id,
                    // La publication signalée n'est plus montrée : on revient au fil.
                    onRemoved: () {
                      if (mounted && context.canPop()) context.pop();
                    }),
              );
            }
            if (i == 1) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    '${l10n.t('forum.comments.title')} · ${post.commentsCount}',
                    key: const ValueKey('post-comments-title'),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.of(context).textSecondary),
                  ),
                ),
              );
            }
            if (comments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Text(l10n.t('forum.comments.empty'),
                    key: const ValueKey('post-comments-empty'),
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.of(context).textSecondary)),
              );
            }
            final index = i - 2;
            if (index >= comments.length) {
              return state.loadMoreFailed
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Text(l10n.t('home.results.loadMoreError')),
                          TextButton(
                            key: const ValueKey('post-more-retry'),
                            onPressed: () => ref
                                .read(
                                    postThreadProvider(widget.postId).notifier)
                                .loadMore(),
                            style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48)),
                            child: Text(l10n.t('profile.retry')),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Semantics(
                        label: l10n.t('posts.loading'),
                        liveRegion: true,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    );
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 0, 20, index == comments.length - 1 ? 20 : 14),
              child: _CommentBubble(
                comment: comments[index],
                now: now,
                offline: ref.watch(offlineProvider),
                onReport: () => openReport(context,
                    target: ReportTarget.comment, id: comments[index].id),
              ),
            );
          },
        );
    }
  }

  Widget _composer(BuildContext context, ThreadState state) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final offline = ref.watch(offlineProvider);
    final disabled = state.sending || offline;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        color: c.navBackground,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (offline)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(l10n.t('forum.comment.offline'),
                    key: const ValueKey('post-offline'),
                    style: TextStyle(fontSize: 12, color: c.textSecondary)),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('comment-field'),
                  controller: _text,
                  enabled: !disabled,
                  maxLength: kMaxCommentLength,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(fontSize: 14),
                  onChanged: (_) => setState(() {}),
                  buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      Text('$currentLength/$maxLength',
                          key: const ValueKey('comment-counter'),
                          style:
                              TextStyle(fontSize: 11, color: c.textSecondary)),
                  decoration: InputDecoration(
                    hintText: l10n.t('forum.comment.hint'),
                    filled: true,
                    fillColor: c.card,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: c.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: c.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton.filled(
                  key: const ValueKey('comment-send'),
                  tooltip: l10n.t('forum.comment.send'),
                  onPressed:
                      disabled || _text.text.trim().isEmpty ? null : _send,
                  icon: const Icon(Icons.send, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader(
      {required this.post,
      required this.now,
      required this.onReport,
      required this.offline});

  final FeedPost post;
  final DateTime now;
  final VoidCallback onReport;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final ago = postAgo(l10n, post.createdAt, now);
    final where = post.zoneName.isEmpty ? ago : '${post.zoneName} · $ago';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              AuthorAvatar(initials: post.initials, photo: post.authorPhoto),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorName,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(where,
                        style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  ],
                ),
              ),
              if (!post.isMine)
                ReportMenuButton(
                  key: const ValueKey('post-report'),
                  tooltip: l10n.t(
                      offline ? 'report.post.offline' : 'report.post.action'),
                  onPressed: offline ? null : onReport,
                ),
            ],
          ),
        ),
        PostMedia(type: post.mediaType, url: post.mediaUrl, height: 200),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Texte simple : jamais interprété.
              Text(post.caption,
                  key: const ValueKey('post-caption'),
                  style: const TextStyle(fontSize: 14, height: 1.5)),
              if (post.offerName != null) ...[
                const SizedBox(height: 10),
                Align(
                    alignment: Alignment.centerLeft,
                    child: ProductTag(name: post.offerName!)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble(
      {required this.comment,
      required this.now,
      required this.onReport,
      required this.offline});

  final ForumComment comment;
  final DateTime now;
  final VoidCallback onReport;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return Opacity(
      opacity: comment.pending ? 0.6 : 1,
      child: Row(
        key: ValueKey(comment.pending
            ? 'comment-pending-${comment.id}'
            : 'comment-${comment.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthorAvatar(
            initials: comment.initials,
            photo: comment.authorPhoto,
            size: 30,
            fontSize: 11,
            highlighted: false,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.card,
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(comment.authorName,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      // Texte simple : jamais interprété.
                      Text(comment.text,
                          style: const TextStyle(fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    comment.pending
                        ? l10n.t('forum.comment.sending')
                        : postAgo(l10n, comment.createdAt, now),
                    style: TextStyle(fontSize: 11, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          if (!comment.isMine && !comment.pending)
            ReportMenuButton(
              key: ValueKey('comment-report-${comment.id}'),
              tooltip: l10n.t(
                  offline ? 'report.comment.offline' : 'report.comment.action'),
              onPressed: offline ? null : onReport,
            ),
        ],
      ),
    );
  }
}
