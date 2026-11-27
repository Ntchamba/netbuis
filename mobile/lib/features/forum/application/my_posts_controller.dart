import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../search/application/offline_controller.dart';
import '../data/models/post.dart';
import 'forum_services.dart';

/// Mes publications (GET /api/forum/mine/), chargées à l'ouverture de l'écran. À n'utiliser
/// que si le compte business est actif (sinon le serveur répond 403 `business_not_active`).
final myPostsProvider =
    AsyncNotifierProvider.autoDispose<MyPostsController, List<MyPost>>(MyPostsController.new);

class MyPostsController extends AsyncNotifier<List<MyPost>> {
  @override
  Future<List<MyPost>> build() => _load();

  Future<List<MyPost>> _load() async {
    try {
      final list = await ref.read(forumRepositoryProvider).listMine();
      if (ref.mounted) ref.read(offlineProvider.notifier).set(false);
      return list;
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.network && ref.mounted) {
        ref.read(offlineProvider.notifier).set(true);
      }
      rethrow;
    }
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Supprime la publication (suppression douce côté serveur) ; lève [ApiException] si le
  /// serveur refuse : la liste reste inchangée.
  Future<void> delete(int id) async {
    await ref.read(forumRepositoryProvider).deletePost(id);
    if (!ref.mounted) return;
    state = AsyncData([
      for (final p in state.value ?? const <MyPost>[])
        if (p.id != id) p,
    ]);
  }
}
