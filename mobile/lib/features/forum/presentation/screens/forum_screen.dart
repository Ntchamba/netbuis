import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../business/application/business_controller.dart';
import '../../../business/data/models/business.dart';
import '../../application/comment_errors.dart';
import '../../application/forum_feed_controller.dart';
import '../widgets/feed_post_card.dart';

/// Onglet Forum (maquette Forum) : le fil des publications des commerçants de la ville choisie.
/// Tirer pour rafraîchir, suite chargée en bas de liste, bouton « + » pour un compte business actif.
class ForumScreen extends ConsumerStatefulWidget {
  const ForumScreen({super.key});

  @override
  ConsumerState<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends ConsumerState<ForumScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 300) {
        ref.read(forumFeedProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(forumFeedProvider.notifier).refresh();
    if (!ok && mounted) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.t('forum.refresh.error'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final state = ref.watch(forumFeedProvider);
    final canPublish =
        ref.watch(myBusinessProvider).value?.status == BusinessStatus.active;
    return SafeArea(
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(l10n.t('forum.title'),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 2),
                    Text(l10n.t('forum.subtitle'),
                        style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  ],
                ),
              ),
              if (state.fromCache)
                Container(
                  key: const ValueKey('forum-offline'),
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.card,
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(l10n.t('forum.offline.banner'),
                        style: TextStyle(
                            fontSize: 12, height: 1.3, color: c.textSecondary)),
                  ),
                ),
              Expanded(child: _body(context, state)),
            ],
          ),
          if (canPublish)
            Positioned(
              right: 20,
              bottom: 20,
              child: Semantics(
                button: true,
                label: l10n.t('forum.publish.aria'),
                child: Material(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 6,
                  child: InkWell(
                    key: const ValueKey('forum-publish'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.push(Routes.publish),
                    child: const SizedBox(
                      width: 52,
                      height: 52,
                      child: ExcludeSemantics(
                          child: Icon(Icons.add,
                              size: 24, color: AppColors.onAccent)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, FeedState state) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    switch (state.status) {
      case FeedStatus.idle:
      case FeedStatus.loading:
        return Semantics(
          label: l10n.t('posts.loading'),
          liveRegion: true,
          child: const Center(child: CircularProgressIndicator()),
        );
      case FeedStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(l10n.t(forumLoadErrorKey(state.error)),
                      key: const ValueKey('forum-error'),
                      textAlign: TextAlign.center),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const ValueKey('forum-retry'),
                  onPressed: () => ref.read(forumFeedProvider.notifier).retry(),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text(l10n.t('profile.retry')),
                ),
              ],
            ),
          ),
        );
      case FeedStatus.empty:
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.t('forum.empty'),
                  key: const ValueKey('forum-empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, height: 1.4, color: c.textSecondary),
                ),
              ),
            ],
          ),
        );
      case FeedStatus.results:
        final now = DateTime.now();
        final extra = state.loadingMore || state.loadMoreFailed ? 1 : 0;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
            itemCount: state.items.length + extra,
            itemBuilder: (context, i) {
              if (i >= state.items.length) {
                return state.loadMoreFailed
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            Text(l10n.t('home.results.loadMoreError')),
                            TextButton(
                              key: const ValueKey('forum-more-retry'),
                              onPressed: () => ref
                                  .read(forumFeedProvider.notifier)
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
                          child:
                              const Center(child: CircularProgressIndicator()),
                        ),
                      );
              }
              final post = state.items[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FeedPostCard(
                  post: post,
                  now: now,
                  onOpen: () => context.push(Routes.forumPostPath(post.id)),
                ),
              );
            },
          ),
        );
    }
  }
}
