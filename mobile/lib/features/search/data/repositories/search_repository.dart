// Contrat du dépôt de recherche : texte, suggestions, texte vocal reconnu
import '../models/search_query.dart';
import '../models/search_result.dart';
import '../models/suggestion.dart';

abstract class SearchRepository {
  /// GET /api/search/ — une page (à partir de 1). `q` vide = commerces de la zone.
  Future<SearchPage> search(SearchQuery query, {int page = 1});

  /// GET /api/search/suggestions/ — 8 au plus ; liste vide si [q] a moins de 2 caractères.
  Future<List<Suggestion>> suggestions(String q);

  /// POST /api/search/voice/ — [text] est la phrase reconnue par le téléphone (300 caractères au plus).
  /// Le terme nettoyé revient dans [SearchPage.cleanedQuery].
  Future<SearchPage> voiceSearch(String text, {int? zone, String? sector, int page = 1});
}
