import '../../../core/network/api_exception.dart';

/// Clé de texte traduit pour une erreur d'envoi de commentaire. Jamais le texte du serveur.
String commentErrorKey(Object error) {
  if (error is ApiException) {
    if (error.code == ApiErrorCode.network) {
      return 'forum.comment.error.network';
    }
    if (error.code == ApiErrorCode.accountBlocked ||
        error.code == ApiErrorCode.accountDeleted ||
        error.serverCode == 'account_blocked') {
      return 'forum.comment.error.blocked';
    }
    if (error.statusCode == 429 || error.serverCode == 'comment_rate_limit') {
      return 'forum.comment.error.rate';
    }
    if (error.statusCode == 404) return 'forum.comment.error.gone';
    if (error.code == ApiErrorCode.invalid) {
      return 'forum.comment.error.invalid';
    }
  }
  return 'forum.comment.error.unknown';
}

/// Clé de texte traduit pour une erreur de chargement du fil ou d'une publication.
String forumLoadErrorKey(Object? error) {
  if (error is ApiException) {
    if (error.code == ApiErrorCode.network) return 'forum.error.network';
    if (error.statusCode == 404) return 'forum.post.gone';
    if (error.code == ApiErrorCode.accountBlocked ||
        error.serverCode == 'account_blocked') {
      return 'forum.error.blocked';
    }
  }
  return 'forum.error.unknown';
}
