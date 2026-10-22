import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env.dart';
import '../../../core/di/providers.dart';
import '../data/forum_feed_cache.dart';
import '../data/post_media_service.dart';
import '../data/repositories/forum_feed_repository.dart';
import '../data/repositories/forum_feed_repository_api.dart';
import '../data/repositories/forum_feed_repository_fake.dart';
import '../data/repositories/forum_repository.dart';
import '../data/repositories/forum_repository_api.dart';
import '../data/repositories/forum_repository_fake.dart';
import '../data/repositories/report_repository.dart';
import '../data/repositories/report_repository_api.dart';
import '../data/repositories/report_repository_fake.dart';

/// Dépôt du forum : factice si `USE_FAKE_API=true`, sinon relié à l'API.
final forumRepositoryProvider = Provider<ForumRepository>((ref) {
  if (Env.useFakeApi) return ForumRepositoryFake();
  return ForumRepositoryApi(ref.read(dioProvider));
});

/// Dépôt du fil et des commentaires (T092) : factice si `USE_FAKE_API=true`.
final forumFeedRepositoryProvider = Provider<ForumFeedRepository>((ref) {
  if (Env.useFakeApi) return ForumFeedRepositoryFake();
  return ForumFeedRepositoryApi(ref.read(dioProvider));
});

/// Dépôt des signalements (T093) : factice si `USE_FAKE_API=true` (il masque alors les contenus
/// signalés dans le fil factice), sinon relié à l'API.
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  if (Env.useFakeApi) {
    final feed = ref.read(forumFeedRepositoryProvider);
    return ReportRepositoryFake(feed is ForumFeedRepositoryFake ? feed : null);
  }
  return ReportRepositoryApi(ref.read(dioProvider));
});

/// Mémoire du dernier fil réussi (hors connexion).
final forumFeedCacheProvider =
    Provider<ForumFeedCache>((ref) => SharedForumFeedCache());

/// Ouvre une adresse hors de l'application (la vidéo d'une publication, à la demande).
/// Renvoie faux si rien ne peut l'ouvrir. Remplaçable dans les tests.
final externalUrlOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Appareil photo, caméra vidéo et galerie pour les publications (remplaçable dans les tests).
final postMediaPickerProvider =
    Provider<PostMediaPicker>((ref) => ImagePickerPostMediaPicker());
