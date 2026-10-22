import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/di/providers.dart';
import '../data/post_media_service.dart';
import '../data/repositories/forum_repository.dart';
import '../data/repositories/forum_repository_api.dart';
import '../data/repositories/forum_repository_fake.dart';

/// Dépôt du forum : factice si `USE_FAKE_API=true`, sinon relié à l'API.
final forumRepositoryProvider = Provider<ForumRepository>((ref) {
  if (Env.useFakeApi) return ForumRepositoryFake();
  return ForumRepositoryApi(ref.read(dioProvider));
});

/// Appareil photo, caméra vidéo et galerie pour les publications (remplaçable dans les tests).
final postMediaPickerProvider =
    Provider<PostMediaPicker>((ref) => ImagePickerPostMediaPicker());
