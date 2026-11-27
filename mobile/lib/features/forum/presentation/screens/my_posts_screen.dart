import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/upload_url.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/my_posts_controller.dart';
import '../../application/post_publisher.dart';
import '../../application/post_time.dart';
import '../../data/models/post.dart';
import '../widgets/active_business_gate.dart';

/// « Mes publications » (maquette MesPublications) : mes publications avec date et nombre
/// de commentaires, statut « masquée », suppression avec confirmation. Réservé au compte
/// business actif.
class MyPostsScreen extends ConsumerWidget {
  const MyPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    key: const ValueKey('posts-back'),
                    onPressed: () => context.pop(),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: c.textSecondary,
                    ),
                    icon: const Icon(Icons.chevron_left, size: 20),
                    label: Text(l10n.t('history.back'), style: const TextStyle(fontSize: 13)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(l10n.t('posts.mine.title'),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          key: const ValueKey('posts-publish'),
                          onPressed: () => context.push(Routes.publish),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(l10n.t('posts.publish'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(child: ActiveBusinessGate(builder: _buildList)),
          ],
        ),
      ),
    );
  }

  static Widget _buildList(BuildContext context) => const _PostsList();
}

class _PostsList extends ConsumerWidget {
  const _PostsList();

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, MyPost post) async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.t('posts.delete.title')),
        content: Text(l10n.t('posts.delete.body')),
        actions: [
          TextButton(
            key: const ValueKey('posts-delete-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.t('offers.delete.cancel')),
          ),
          TextButton(
            key: const ValueKey('posts-delete-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.t('offers.delete.confirm')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(myPostsProvider.notifier).delete(post.id);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.t(postErrorKey(e)))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final posts = ref.watch(myPostsProvider);
    return posts.when(
      loading: () => Semantics(
        label: l10n.t('posts.loading'),
        liveRegion: true,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => error is ApiException &&
              error.statusCode == 403 &&
              error.serverCode == 'business_not_active'
          ? const PostsNotActive(rejected: false)
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(l10n.t(postErrorKey(error)),
                          key: const ValueKey('posts-list-error'), textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const ValueKey('posts-retry'),
                      onPressed: () => ref.read(myPostsProvider.notifier).reload(),
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      child: Text(l10n.t('profile.retry')),
                    ),
                  ],
                ),
              ),
            ),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.t('posts.mine.empty'),
                key: const ValueKey('posts-empty'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.4, color: c.textSecondary),
              ),
            ),
          );
        }
        final now = DateTime.now();
        return RefreshIndicator(
          onRefresh: () => ref.read(myPostsProvider.notifier).reload(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, i) => _PostCard(
              post: list[i],
              now: now,
              onDelete: () => _confirmDelete(context, ref, list[i]),
            ),
          ),
        );
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.now, required this.onDelete});

  final MyPost post;
  final DateTime now;
  final VoidCallback onDelete;

  String? get _url {
    final u = post.mediaUrl;
    if (u == null) return null;
    try {
      return resolveUploadUrl(Env.apiUrl, u);
    } on ApiException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final placeholder = ColoredBox(
      color: dark ? const Color(0xFF15151A) : const Color(0xFFEFEFF2),
      child: Center(
        child: Icon(
          post.mediaType == PostMediaType.video ? Icons.play_circle_outline : Icons.image_outlined,
          size: 30,
          color: dark ? const Color(0xFF3A3A40) : const Color(0xFFC8C8CE),
        ),
      ),
    );
    final url = _url;
    final comments = post.commentsCount == 0
        ? l10n.t('posts.comments.none')
        : post.commentsCount == 1
            ? l10n.t('posts.comments.one')
            : l10n.t('posts.comments.other').replaceAll('{n}', '${post.commentsCount}');
    final ago = postAgo(l10n, post.createdAt, now);
    return DecoratedBox(
      key: ValueKey('post-${post.id}'),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 150,
              child: url == null || post.mediaType == PostMediaType.video
                  ? placeholder
                  : Image.network(url,
                      fit: BoxFit.cover,
                      cacheWidth: 780,
                      errorBuilder: (context, _, __) => placeholder),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.isHidden) ...[
                    Container(
                      key: ValueKey('post-hidden-${post.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: c.accentText),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(l10n.t('posts.hidden'),
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700, color: c.accentText)),
                    ),
                    const SizedBox(height: 4),
                    Text(l10n.t('posts.hidden.note'),
                        style: TextStyle(fontSize: 11.5, height: 1.3, color: c.textSecondary)),
                    const SizedBox(height: 6),
                  ],
                  Text(post.caption, style: const TextStyle(fontSize: 13, height: 1.4)),
                  if (post.offerName != null) ...[
                    const SizedBox(height: 4),
                    Text(post.offerName!, style: TextStyle(fontSize: 12, color: c.accentText)),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 4, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 2,
                      children: [
                        Text(ago,
                            key: ValueKey('post-time-${post.id}'),
                            style: TextStyle(fontSize: 11, color: c.textSecondary)),
                        Text(comments,
                            key: ValueKey('post-comments-${post.id}'),
                            style: TextStyle(fontSize: 11, color: c.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    key: ValueKey('post-delete-${post.id}'),
                    tooltip: l10n.t('posts.delete.action'),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
