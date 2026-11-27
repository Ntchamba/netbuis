import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/post_time.dart';
import '../../data/models/feed_post.dart';
import 'post_visuals.dart';
import 'report_menu_button.dart';

/// Texte « n commentaires · écrire un commentaire » de la carte (maquette Forum).
String feedCommentsLabel(L10n l10n, int count) => count == 1
    ? l10n.t('forum.card.comments.one')
    : l10n.t('forum.card.comments.other').replaceAll('{n}', '$count');

/// Une carte du fil (maquette Forum) : commerce, zone · il y a x h, média, légende,
/// étiquette produit, « n commentaires ». Toucher le média ou la ligne des commentaires
/// ouvre la page de la publication.
class FeedPostCard extends StatelessWidget {
  const FeedPostCard(
      {super.key,
      required this.post,
      required this.now,
      required this.onOpen,
      this.onReport,
      this.offline = false});

  final FeedPost post;
  final DateTime now;
  final VoidCallback onOpen;

  /// Menu discret ⋯ « Signaler » (T093) ; absent sur mes propres publications.
  final VoidCallback? onReport;

  /// Hors connexion : « Signaler » est désactivé.
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final ago = postAgo(l10n, post.createdAt, now);
    final where = post.zoneName.isEmpty ? ago : '${post.zoneName} · $ago';
    return DecoratedBox(
      key: ValueKey('feed-post-${post.id}'),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  AuthorAvatar(
                      initials: post.initials, photo: post.authorPhoto),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        Text(where,
                            key: ValueKey('feed-where-${post.id}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: c.textSecondary)),
                      ],
                    ),
                  ),
                  if (!post.isMine && onReport != null)
                    ReportMenuButton(
                      key: ValueKey('feed-report-${post.id}'),
                      tooltip: l10n.t(offline
                          ? 'report.post.offline'
                          : 'report.post.action'),
                      onPressed: offline ? null : onReport,
                    ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: l10n.t('forum.card.open'),
              excludeSemantics: true,
              child: InkWell(
                key: ValueKey('feed-open-${post.id}'),
                onTap: onOpen,
                child: PostMedia(type: post.mediaType, url: post.mediaUrl),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Texte simple : jamais interprété (ni lien, ni mise en forme).
                  Text(post.caption,
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                  if (post.offerName != null) ...[
                    const SizedBox(height: 10),
                    ProductTag(name: post.offerName!),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Divider(height: 1, color: c.border),
            ),
            InkWell(
              key: ValueKey('feed-comments-${post.id}'),
              onTap: onOpen,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 15, color: c.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(feedCommentsLabel(l10n, post.commentsCount),
                            style: TextStyle(
                                fontSize: 12, color: c.textSecondary)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
