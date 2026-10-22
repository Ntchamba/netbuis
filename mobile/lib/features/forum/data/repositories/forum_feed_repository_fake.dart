// Version factice (USE_FAKE_API) : aucun réseau, publications et commentaires fictifs (sans numéro)
import '../../../../core/network/api_exception.dart';
import '../models/feed_post.dart';
import '../models/post.dart';
import 'forum_feed_repository.dart';

class ForumFeedRepositoryFake implements ForumFeedRepository {
  ForumFeedRepositoryFake({DateTime? now}) {
    _build(now ?? DateTime.now());
  }

  /// Taille d'une page, comme le serveur.
  static const int pageSize = 20;

  /// Zones fictives : le quartier, et la ville qui le contient (la zone choisie filtre
  /// sur la zone ET ses sous-zones, comme le serveur).
  static const int _maroua = 16;
  static const int _garoua = 90;

  final List<({FeedPost post, int zoneId, int cityId})> _posts = [];
  final Map<int, List<ForumComment>> _comments = {};
  int _nextCommentId = 5000;

  void _add(FeedPost post, int zoneId, int cityId) {
    _posts.add((post: post, zoneId: zoneId, cityId: cityId));
  }

  void _build(DateTime now) {
    FeedPost post(int id, String initials, String name, String zone,
            Duration age, String caption,
            {String? offer}) =>
        FeedPost(
          id: id,
          businessId: 100 + id,
          authorName: name,
          initials: initials,
          zoneName: zone,
          mediaType: PostMediaType.image,
          caption: caption,
          offerName: offer,
          createdAt: now.subtract(age),
        );
    _add(
        post(1, 'MA', 'Boutique Mama Aïcha', 'Dougoï', const Duration(hours: 2),
            'Nouveau lot de riz parfumé disponible — 25kg et 50kg, prix de gros.',
            offer: 'Riz 25kg'),
        18,
        _maroua);
    _add(
        post(2, 'IB', 'Couturier Ibrahim', 'Domayo', const Duration(hours: 5),
            'Modèles de boubous pour la rentrée, tissus wax et bazin disponibles.'),
        19,
        _maroua);
    _add(
        post(3, 'EL', 'Électricien qualifié', 'Hardé', const Duration(days: 1),
            'Installation de panneaux solaires résidentiels, devis gratuit sur place.'),
        17,
        _maroua);
    for (var i = 4; i <= 24; i++) {
      _add(
          post(i, 'BM', 'Boutique Maroua $i', 'Hardé', Duration(days: i - 2),
              'Arrivage du jour n°$i : produits frais et prix doux.'),
          17,
          _maroua);
    }
    _add(
        post(25, 'GA', 'Atelier Garoua', 'Garoua', const Duration(hours: 3),
            'Réparation de téléphones et accessoires.'),
        _garoua,
        _garoua);

    ForumComment comment(
            int id, String initials, String name, Duration age, String text,
            {bool business = false}) =>
        ForumComment(
          id: id,
          authorName: name,
          initials: initials,
          text: text,
          createdAt: now.subtract(age),
          isBusiness: business,
        );
    _comments[1] = [
      comment(1, 'JN', 'Jeff N.', const Duration(hours: 1),
          'Le riz 25kg est encore disponible cette semaine ?'),
      comment(2, 'SA', 'Sali A.', const Duration(minutes: 45),
          'Vous livrez aussi vers Djarengol ?'),
      comment(3, 'MA', 'Boutique Mama Aïcha', const Duration(minutes: 30),
          'Oui, livraison possible dans tout Maroua, contactez-nous par appel.',
          business: true),
    ];
    _comments[2] = [
      comment(
          4, 'SA', 'Sali A.', const Duration(hours: 3), 'Très beaux modèles.'),
      comment(5, 'JN', 'Jeff N.', const Duration(hours: 2),
          'Quels prix pour un boubou ?'),
    ];
  }

  FeedPost _withCount(FeedPost p) =>
      p.copyWith(commentsCount: (_comments[p.id] ?? const []).length);

  @override
  Future<ForumPage<FeedPost>> feed({int? zone, int page = 1}) async {
    final all = [
      for (final e in _posts)
        if (zone == null || e.zoneId == zone || e.cityId == zone)
          _withCount(e.post),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final start = (page - 1) * pageSize;
    final items = start >= all.length
        ? <FeedPost>[]
        : all.sublist(start, (start + pageSize).clamp(0, all.length));
    return ForumPage(
        items: items,
        count: all.length,
        hasNext: start + pageSize < all.length);
  }

  FeedPost _find(int id) {
    for (final e in _posts) {
      if (e.post.id == id) return _withCount(e.post);
    }
    throw const ApiException(ApiErrorCode.unknown,
        statusCode: 404, serverCode: 'not_found');
  }

  @override
  Future<FeedPost> getPost(int id) async => _find(id);

  @override
  Future<ForumPage<ForumComment>> comments(int postId, {int page = 1}) async {
    _find(postId);
    final all = _comments[postId] ?? const <ForumComment>[];
    final start = (page - 1) * pageSize;
    final items = start >= all.length
        ? <ForumComment>[]
        : all.sublist(start, (start + pageSize).clamp(0, all.length));
    return ForumPage(
        items: items,
        count: all.length,
        hasNext: start + pageSize < all.length);
  }

  @override
  Future<ForumComment> addComment(int postId, String text) async {
    _find(postId);
    final comment = ForumComment(
      id: _nextCommentId++,
      authorName: 'Moi',
      initials: 'M',
      text: text,
      createdAt: DateTime.now(),
      isMine: true,
    );
    (_comments[postId] ??= []).add(comment);
    return comment;
  }
}
