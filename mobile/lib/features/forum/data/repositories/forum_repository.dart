// Contrat du dépôt du forum, partie « publier » (T091) :
// POST /api/forum/posts/, GET /api/forum/mine/, DELETE /api/forum/posts/{id}/
import '../models/post.dart';

/// Longueur maximale de la légende d'une publication (contrat de l'API).
const int kMaxCaptionLength = 500;

abstract class ForumRepository {
  /// Toutes mes publications, plus récentes d'abord (le dépôt suit les pages `next`).
  /// Lève `ApiException` (403 `business_not_active`, 404 `no_business`…).
  Future<List<MyPost>> listMine();

  /// Crée une publication. [mediaKey] vient de `POST /api/uploads/sign/` (kind `post_image`
  /// ou `post_video`) ; [offerId] est l'une de MES offres, ou `null`.
  /// Lève `ApiException` (400 `SUBSCRIPTION_REQUIRED`, 429 `daily_post_limit`…).
  Future<MyPost> createPost({
    required String mediaKey,
    required String caption,
    int? offerId,
  });

  /// Suppression douce d'une de mes publications.
  Future<void> deletePost(int id);
}
