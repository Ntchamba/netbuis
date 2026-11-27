// Dernier fil réussi, gardé sur le téléphone pour l'afficher hors connexion.
// Seules des données PUBLIQUES y entrent (champs de FeedPost) : jamais de numéro ni de jeton.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/feed_post.dart';

/// Version du format mémorisé : un autre format est ignoré (donc jamais d'erreur à la lecture).
const int kForumFeedCacheVersion = 1;

/// Première page du fil d'une zone.
class CachedFeed {
  const CachedFeed(
      {required this.zone, required this.items, required this.count});

  final int? zone;
  final List<FeedPost> items;
  final int count;

  Map<String, Object?> toJson() => {
        'v': kForumFeedCacheVersion,
        'zone': zone,
        'count': count,
        'results': [for (final p in items) p.toJson()],
      };

  /// Renvoie null si le contenu n'a pas la forme attendue.
  static CachedFeed? fromJson(Object? data) {
    try {
      if (data is! Map<String, dynamic> ||
          data['v'] != kForumFeedCacheVersion) {
        return null;
      }
      final zone = data['zone'];
      final count = data['count'];
      final results = data['results'];
      if ((zone != null && zone is! int) || count is! int || results is! List) {
        return null;
      }
      return CachedFeed(
        zone: zone as int?,
        count: count,
        items: [for (final item in results) FeedPost.fromJson(item)],
      );
    } on Object {
      return null;
    }
  }
}

abstract class ForumFeedCache {
  Future<CachedFeed?> read();
  Future<void> write(CachedFeed value);

  /// Efface tout (déconnexion).
  Future<void> clear();
}

/// Version réelle, au-dessus de `shared_preferences`.
class SharedForumFeedCache implements ForumFeedCache {
  static const key = 'forum_feed_cache_v1';

  @override
  Future<CachedFeed?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return CachedFeed.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(CachedFeed value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}

/// En mémoire : sert aux tests et garde le texte exact qui serait écrit ([raw]).
class MemoryForumFeedCache implements ForumFeedCache {
  String? raw;
  int writes = 0;

  @override
  Future<CachedFeed?> read() async {
    final r = raw;
    if (r == null) return null;
    return CachedFeed.fromJson(jsonDecode(r));
  }

  @override
  Future<void> write(CachedFeed value) async {
    writes++;
    raw = jsonEncode(value.toJson());
  }

  @override
  Future<void> clear() async => raw = null;
}
