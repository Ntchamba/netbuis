// Contrat du dépôt du fil du forum et des commentaires (T092) :
// GET /api/forum/posts/?zone=&page=, GET /api/forum/posts/{id}/,
// GET|POST /api/forum/posts/{id}/comments/
import '../models/feed_post.dart';

/// Longueur maximale d'un commentaire (contrat de l'API).
const int kMaxCommentLength = 300;

abstract class ForumFeedRepository {
  /// Une page du fil (20 par page), plus récentes d'abord ; [zone] = la zone ET ses sous-zones,
  /// absent = toutes. Lève `ApiException`.
  Future<ForumPage<FeedPost>> feed({int? zone, int page = 1});

  /// Une publication (404 `not_found` si absente, masquée, supprimée ou signalée par moi).
  Future<FeedPost> getPost(int id);

  /// Une page de commentaires, du plus ancien au plus récent.
  Future<ForumPage<ForumComment>> comments(int postId, {int page = 1});

  /// Envoie un commentaire (texte brut, 300 caractères au plus).
  /// Lève `ApiException` (429 `comment_rate_limit`, 403 `account_blocked`, réseau…).
  Future<ForumComment> addComment(int postId, String text);
}
