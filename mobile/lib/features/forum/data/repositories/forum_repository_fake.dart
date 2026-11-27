// Version factice (USE_FAKE_API) : aucun réseau, état gardé en mémoire
import '../../../../core/network/api_exception.dart';
import '../models/post.dart';
import 'forum_repository.dart';

class ForumRepositoryFake implements ForumRepository {
  ForumRepositoryFake({List<MyPost>? initial, DateTime? now})
      : _posts = [...(initial ?? _demo(now ?? DateTime.now()))];

  /// Même plafond que le serveur sans abonnement (T090).
  static const int maxActive = 5;

  final List<MyPost> _posts;
  int _nextId = 1000;

  static List<MyPost> _demo(DateTime now) => [
        MyPost(
          id: 1,
          mediaType: PostMediaType.image,
          caption: 'Nouveau lot de riz parfumé disponible — 25kg et 50kg, prix de gros.',
          createdAt: now.subtract(const Duration(hours: 2)),
          commentsCount: 6,
        ),
        MyPost(
          id: 2,
          mediaType: PostMediaType.image,
          caption: 'Promotion sur l’huile de palme ce week-end, dans la limite des stocks.',
          createdAt: now.subtract(const Duration(days: 3)),
          commentsCount: 3,
        ),
        MyPost(
          id: 3,
          mediaType: PostMediaType.image,
          caption: 'Nouveaux arrivages de condiments et épices locales.',
          createdAt: now.subtract(const Duration(days: 7)),
          commentsCount: 1,
        ),
      ];

  @override
  Future<List<MyPost>> listMine() async => List.unmodifiable(_posts);

  @override
  Future<MyPost> createPost({
    required String mediaKey,
    required String caption,
    int? offerId,
  }) async {
    if (_posts.where((p) => !p.isHidden).length >= maxActive) {
      throw const ApiException(ApiErrorCode.unknown,
          statusCode: 400, serverCode: ServerCodes.subscriptionRequired);
    }
    final post = MyPost(
      id: _nextId++,
      mediaType: mediaKey.contains('video') ? PostMediaType.video : PostMediaType.image,
      caption: caption,
      offerId: offerId,
      createdAt: DateTime.now(),
    );
    _posts.insert(0, post);
    return post;
  }

  @override
  Future<void> deletePost(int id) async {
    _posts.removeWhere((p) => p.id == id);
  }
}
