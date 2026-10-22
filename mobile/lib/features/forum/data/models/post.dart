// Une publication de commerçant (forum), telle que le serveur la renvoie.
// T091 : « Mes publications ». Le fil et la page d'une publication (T092) s'appuieront sur ce modèle.

/// Nature du média d'une publication (`media_type`).
enum PostMediaType { image, video }

/// Statut visible par son auteur (`status` de `GET /api/forum/mine/`) : `actif` ou `masque`
/// (masquée par la modération).
enum PostStatus { active, hidden }

class MyPost {
  const MyPost({
    required this.id,
    required this.mediaType,
    required this.caption,
    required this.createdAt,
    this.mediaUrl,
    this.offerId,
    this.offerName,
    this.commentsCount = 0,
    this.status = PostStatus.active,
  });

  final int id;
  final PostMediaType mediaType;

  /// Adresse publique du média (complète ou chemin du serveur) ; `null` si absente.
  final String? mediaUrl;
  final String caption;
  final int? offerId;
  final String? offerName;
  final DateTime createdAt;
  final int commentsCount;
  final PostStatus status;

  bool get isHidden => status == PostStatus.hidden;

  /// Lève [FormatException] si la réponse n'a pas la forme du contrat.
  factory MyPost.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Publication inattendue');
    final id = json['id'];
    final caption = json['caption'];
    final created = json['created_at'];
    if (id is! int || caption is! String || created is! String) {
      throw const FormatException('Publication incomplète');
    }
    final date = DateTime.tryParse(created);
    if (date == null) throw const FormatException('Date invalide');
    final media = json['media_type'];
    final url = json['media_url'];
    final offer = json['offer'];
    final count = json['comments_count'];
    return MyPost(
      id: id,
      mediaType: media == 'video' ? PostMediaType.video : PostMediaType.image,
      mediaUrl: url is String && url.isNotEmpty ? url : null,
      caption: caption,
      offerId: offer is Map && offer['id'] is int ? offer['id'] as int : null,
      offerName: offer is Map && offer['name'] is String ? offer['name'] as String : null,
      createdAt: date.toLocal(),
      commentsCount: count is int ? count : 0,
      status: json['status'] == 'masque' ? PostStatus.hidden : PostStatus.active,
    );
  }
}
