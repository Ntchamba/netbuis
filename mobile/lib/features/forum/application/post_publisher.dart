import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/di/providers.dart';
import '../../business/application/business_services.dart';
import '../../business/data/repositories/business_repository.dart';
import '../../search/application/offline_controller.dart';
import '../data/models/post.dart';
import '../data/post_media.dart';
import '../data/repositories/forum_repository.dart';
import 'forum_services.dart';
import 'my_posts_controller.dart';

/// Étape en cours pendant l'envoi (pour l'afficher à l'écran).
enum PublishStage { uploading, publishing }

/// La légende dépasse [kMaxCaptionLength] : rien n'est envoyé.
class CaptionTooLongException implements Exception {
  const CaptionTooLongException();
}

/// Publier : vérifie le fichier d'après ses octets, l'envoie (signature puis PUT), puis crée
/// la publication avec la clé reçue. Si l'envoi du fichier échoue, AUCUNE publication n'est créée.
final postPublisherProvider = Provider<PostPublisher>((ref) => PostPublisher(ref));

class PostPublisher {
  PostPublisher(this._ref);

  final Ref _ref;

  Future<Uint8List> _read(String path) async {
    try {
      return await _ref.read(photoBytesReaderProvider)(path);
    } on Object {
      throw const PostMediaException(tooLarge: false);
    }
  }

  /// Contrôle un fichier choisi : lève [PostMediaException] (format refusé ou trop gros).
  Future<PostMediaInfo> inspect(String path) async => checkPostMedia(await _read(path));

  /// Lève [ApiException], [PostMediaException] ou [CaptionTooLongException]. La liste de mes
  /// publications n'est rechargée qu'en cas de succès.
  Future<MyPost> publish({
    required String path,
    required String caption,
    int? offerId,
    void Function(PublishStage stage)? onStage,
  }) async {
    final text = caption.trim();
    if (text.length > kMaxCaptionLength) throw const CaptionTooLongException();
    final bytes = await _read(path);
    final info = checkPostMedia(bytes);
    final offline = _ref.read(offlineProvider.notifier);
    try {
      onStage?.call(PublishStage.uploading);
      final key = await _upload(bytes, info);
      onStage?.call(PublishStage.publishing);
      final post = await _ref
          .read(forumRepositoryProvider)
          .createPost(mediaKey: key, caption: text, offerId: offerId);
      if (_ref.mounted) {
        offline.set(false);
        _ref.invalidate(myPostsProvider);
      }
      return post;
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.network && _ref.mounted) offline.set(true);
      rethrow;
    }
  }

  /// Vrai si le serveur répond ; met à jour le drapeau « hors connexion » (T055).
  Future<bool> checkConnection() async {
    final offline = _ref.read(offlineProvider.notifier);
    try {
      await _ref.read(forumRepositoryProvider).listMine();
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.network) {
        offline.set(true);
        return false;
      }
    }
    offline.set(false);
    return true;
  }

  /// Signe puis envoie UN fichier ; une seule nouvelle tentative si l'adresse d'envoi est refusée.
  Future<String> _upload(Uint8List bytes, PostMediaInfo info) async {
    final BusinessRepository repo = _ref.read(businessRepositoryProvider);
    for (var attempt = 0;; attempt++) {
      try {
        final ticket = await repo.signUpload(
          kind: info.signKind,
          contentType: info.contentType,
          size: bytes.length,
        );
        await repo.putFile(ticket, bytes);
        return ticket.key;
      } on ApiException catch (e) {
        if (e.statusCode == 403 && attempt == 0) continue;
        if (e.serverCode == ServerCodes.invalidType ||
            e.serverCode == ServerCodes.invalidContent) {
          throw const PostMediaException(tooLarge: false);
        }
        if (e.serverCode == ServerCodes.tooLarge || e.statusCode == 413) {
          throw const PostMediaException(tooLarge: true);
        }
        rethrow;
      }
    }
  }
}

/// Clé de texte traduit pour une erreur de publication ou de suppression. Jamais le texte du serveur.
String postErrorKey(Object error) {
  if (error is PostMediaException) {
    return error.tooLarge ? 'posts.error.tooLarge' : 'posts.error.media';
  }
  if (error is CaptionTooLongException) return 'posts.error.caption';
  if (error is ApiException) {
    if (error.code == ApiErrorCode.network) return 'posts.error.network';
    if (error.serverCode == ServerCodes.subscriptionRequired) return 'posts.error.cap';
    if (error.serverCode == 'daily_post_limit' || error.statusCode == 429) {
      return 'posts.error.daily';
    }
    if (error.statusCode == 403 && error.serverCode == 'business_not_active') {
      return 'posts.error.notActive';
    }
    if (error.serverCode == ServerCodes.noBusiness) return 'posts.error.noBusiness';
    if (error.code == ApiErrorCode.invalid) return 'posts.error.invalid';
  }
  return 'posts.error.unknown';
}
