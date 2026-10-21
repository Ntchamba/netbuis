// Dernier résultat de recherche réussi, gardé sur le téléphone pour l'afficher hors connexion.
// Seules des données PUBLIQUES y entrent (champs de SearchResult) : jamais de numéro,
// de lien wa.me ni de jeton.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/search_query.dart';
import 'models/search_result.dart';

/// Version du format mémorisé : un autre format est ignoré (donc jamais d'erreur à la lecture).
const int kSearchCacheVersion = 1;

/// Requête + filtres + première page de résultats.
class CachedSearch {
  const CachedSearch({
    required this.query,
    required this.items,
    required this.count,
    this.voice = false,
  });

  final SearchQuery query;
  final List<SearchResult> items;
  final int count;

  /// La recherche venait de la voix.
  final bool voice;

  Map<String, Object?> toJson() => {
        'v': kSearchCacheVersion,
        'q': query.q,
        'zone': query.zone,
        'sector': query.sector,
        'voice': voice,
        'count': count,
        'results': [for (final r in items) r.toJson()],
      };

  /// Renvoie null si le contenu n'a pas la forme attendue.
  static CachedSearch? fromJson(Object? data) {
    try {
      if (data is! Map<String, dynamic> || data['v'] != kSearchCacheVersion) {
        return null;
      }
      final q = data['q'];
      final zone = data['zone'];
      final sector = data['sector'];
      final count = data['count'];
      final results = data['results'];
      if (q is! String ||
          (zone != null && zone is! int) ||
          (sector != null && sector is! String) ||
          count is! int ||
          results is! List) {
        return null;
      }
      return CachedSearch(
        query: SearchQuery(q: q, zone: zone as int?, sector: sector as String?),
        count: count,
        voice: data['voice'] == true,
        items: [
          for (final item in results)
            SearchResult.fromJson(item as Map<String, dynamic>),
        ],
      );
    } on Object {
      return null;
    }
  }
}

abstract class SearchCache {
  Future<CachedSearch?> read();
  Future<void> write(CachedSearch value);

  /// Efface tout (déconnexion).
  Future<void> clear();
}

/// Version réelle, au-dessus de `shared_preferences`.
class SharedSearchCache implements SearchCache {
  static const key = 'search_cache_v1';

  @override
  Future<CachedSearch?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return CachedSearch.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(CachedSearch value) async {
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
class MemorySearchCache implements SearchCache {
  String? raw;
  int writes = 0;

  @override
  Future<CachedSearch?> read() async {
    final r = raw;
    if (r == null) return null;
    return CachedSearch.fromJson(jsonDecode(r));
  }

  @override
  Future<void> write(CachedSearch value) async {
    writes++;
    raw = jsonEncode(value.toJson());
  }

  @override
  Future<void> clear() async => raw = null;
}
