// Fil du forum (T092) : une publication vue par tout le monde, ses commentaires, une page de résultats.
// Aucune donnée privée : jamais de numéro de téléphone (le serveur n'en renvoie pas).
import 'post.dart';

/// Une page de résultats paginés (`count`, `next`, `results`).
class ForumPage<T> {
  const ForumPage(
      {required this.items, required this.count, required this.hasNext});

  final List<T> items;
  final int count;
  final bool hasNext;

  /// Lève [FormatException] si la réponse n'a pas la forme `{count, next, results}`.
  static ForumPage<T> fromJson<T>(Object? json, T Function(Object?) parseItem) {
    if (json is! Map || json['results'] is! List) {
      throw const FormatException('Page inattendue');
    }
    final results = json['results'] as List;
    final count = json['count'];
    return ForumPage<T>(
      items: [for (final item in results) parseItem(item)],
      count: count is int ? count : results.length,
      hasNext: json['next'] != null,
    );
  }
}

/// Initiales de secours quand le serveur n'en donne pas (deux lettres au plus, en majuscules).
String initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  String letter(String word) => String.fromCharCode(word.runes.first);
  final second = parts.length > 1 ? letter(parts[1]) : '';
  return '${letter(parts.first)}$second'.toUpperCase();
}

/// Une publication du fil.
class FeedPost {
  const FeedPost({
    required this.id,
    required this.businessId,
    required this.authorName,
    required this.initials,
    required this.mediaType,
    required this.caption,
    required this.createdAt,
    this.authorPhoto,
    this.zoneName = '',
    this.mediaUrl,
    this.offerName,
    this.commentsCount = 0,
    this.isMine = false,
  });

  final int id;
  final int businessId;

  /// Nom du commerce.
  final String authorName;
  final String initials;

  /// Photo du commerce (adresse complète ou chemin du serveur), sinon on montre les initiales.
  final String? authorPhoto;
  final String zoneName;
  final PostMediaType mediaType;
  final String? mediaUrl;

  /// Texte brut : toujours affiché tel quel, jamais interprété.
  final String caption;

  /// Produit associé (étiquette), sinon null.
  final String? offerName;
  final DateTime createdAt;
  final int commentsCount;
  final bool isMine;

  FeedPost copyWith({int? commentsCount}) => FeedPost(
        id: id,
        businessId: businessId,
        authorName: authorName,
        initials: initials,
        authorPhoto: authorPhoto,
        zoneName: zoneName,
        mediaType: mediaType,
        mediaUrl: mediaUrl,
        caption: caption,
        offerName: offerName,
        createdAt: createdAt,
        commentsCount: commentsCount ?? this.commentsCount,
        isMine: isMine,
      );

  /// Lève [FormatException] si la réponse n'a pas la forme du contrat.
  factory FeedPost.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Publication inattendue');
    final id = json['id'];
    final caption = json['caption'];
    final created = json['created_at'];
    final author = json['author'];
    if (id is! int ||
        caption is! String ||
        created is! String ||
        author is! Map) {
      throw const FormatException('Publication incomplète');
    }
    final name = author['name'];
    if (name is! String) throw const FormatException('Auteur incomplet');
    final date = DateTime.tryParse(created);
    if (date == null) throw const FormatException('Date invalide');
    final initials = author['initials'];
    final photo = author['photo'];
    final zone = author['zone'];
    final url = json['media_url'];
    final offer = json['offer'];
    final count = json['comments_count'];
    return FeedPost(
      id: id,
      businessId:
          author['business_id'] is int ? author['business_id'] as int : 0,
      authorName: name,
      initials: initials is String && initials.isNotEmpty
          ? initials
          : initialsOf(name),
      authorPhoto: photo is String && photo.isNotEmpty ? photo : null,
      zoneName:
          zone is Map && zone['name'] is String ? zone['name'] as String : '',
      mediaType: json['media_type'] == 'video'
          ? PostMediaType.video
          : PostMediaType.image,
      mediaUrl: url is String && url.isNotEmpty ? url : null,
      caption: caption,
      offerName: offer is Map && offer['name'] is String
          ? offer['name'] as String
          : null,
      createdAt: date.toLocal(),
      commentsCount: count is int ? count : 0,
      isMine: json['is_mine'] == true,
    );
  }

  /// Pour la mémoire du dernier fil (mêmes clés que le serveur).
  Map<String, Object?> toJson() => {
        'id': id,
        'author': {
          'business_id': businessId,
          'name': authorName,
          'initials': initials,
          'photo': authorPhoto,
          'zone': {'id': 0, 'name': zoneName},
        },
        'media_type': mediaType == PostMediaType.video ? 'video' : 'image',
        'media_url': mediaUrl,
        'caption': caption,
        'offer': offerName == null ? null : {'id': 0, 'name': offerName},
        'created_at': createdAt.toUtc().toIso8601String(),
        'comments_count': commentsCount,
        'is_mine': isMine,
      };
}

/// Un commentaire (texte brut de 300 caractères au plus).
class ForumComment {
  const ForumComment({
    required this.id,
    required this.authorName,
    required this.initials,
    required this.text,
    required this.createdAt,
    this.authorPhoto,
    this.isBusiness = false,
    this.isMine = false,
    this.pending = false,
  });

  /// Identifiant du serveur ; négatif tant que le commentaire est en cours d'envoi.
  final int id;
  final String authorName;
  final String initials;
  final String? authorPhoto;
  final bool isBusiness;
  final String text;
  final DateTime createdAt;
  final bool isMine;

  /// Vrai : affiché tout de suite, pas encore confirmé par le serveur.
  final bool pending;

  /// Lève [FormatException] si la réponse n'a pas la forme du contrat.
  factory ForumComment.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Commentaire inattendu');
    final id = json['id'];
    final text = json['text'];
    final created = json['created_at'];
    final author = json['author'];
    if (id is! int || text is! String || created is! String || author is! Map) {
      throw const FormatException('Commentaire incomplet');
    }
    final name = author['name'];
    if (name is! String) throw const FormatException('Auteur incomplet');
    final date = DateTime.tryParse(created);
    if (date == null) throw const FormatException('Date invalide');
    final initials = author['initials'];
    final photo = author['photo'];
    return ForumComment(
      id: id,
      authorName: name,
      initials: initials is String && initials.isNotEmpty
          ? initials
          : initialsOf(name),
      authorPhoto: photo is String && photo.isNotEmpty ? photo : null,
      isBusiness: author['is_business'] == true,
      text: text,
      createdAt: date.toLocal(),
      isMine: json['is_mine'] == true,
    );
  }
}
