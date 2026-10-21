// Version factice (USE_FAKE_API) : aucun réseau, quelques commerces de Maroua en mémoire
import '../../../../core/data/zones/zone_repository.dart';
import '../../../../core/data/zones/zone_repository_fake.dart';
import '../../../../core/network/api_exception.dart';
import '../models/search_query.dart';
import '../models/search_result.dart';
import '../models/suggestion.dart';
import 'search_repository.dart';

class SearchRepositoryFake implements SearchRepository {
  /// [pageSize] : 20 comme le serveur ; plus petit dans les tests de pagination.
  SearchRepositoryFake({
    List<SearchResult>? data,
    ZoneRepository? zones,
    this.pageSize = 20,
  })  : _data = data ?? _demo,
        _zones = zones ?? ZoneRepositoryFake();

  final List<SearchResult> _data;
  final ZoneRepository _zones;
  final int pageSize;

  static String _plain(String s) {
    const from = 'àâäéèêëîïôöùûüçœ';
    const to = 'aaaeeeeiioouuuco';
    final low = s.toLowerCase();
    final out = StringBuffer();
    for (final c in low.split('')) {
      final i = from.indexOf(c);
      out.write(i < 0 ? c : to[i]);
    }
    return out.toString();
  }

  Future<bool> _inZone(SearchResult r, int? zone) async {
    if (zone == null) return true;
    if (r.zone == null) return false;
    try {
      final detail = await _zones.getZone(r.zone!.id);
      return detail.path.any((p) => p.id == zone);
    } on ApiException {
      return false;
    }
  }

  Future<SearchPage> _page(String q, int? zone, String? sector, int page) async {
    if (zone != null) {
      try {
        await _zones.getZone(zone);
      } on ApiException {
        throw const ApiException(ApiErrorCode.invalid, statusCode: 400, serverCode: 'invalid');
      }
    }
    final words = _plain(q).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final found = <SearchResult>[];
    for (final r in _data) {
      if (sector != null && sector.isNotEmpty && r.secteurCode != sector) continue;
      if (!await _inZone(r, zone)) continue;
      final hay = _plain('${r.name} ${r.secteur} ${r.descriptionActivite} ${r.repere}');
      if (words.every(hay.contains)) found.add(r);
    }
    final start = (page - 1) * pageSize;
    final slice = start >= found.length
        ? <SearchResult>[]
        : found.sublist(start, (start + pageSize).clamp(0, found.length));
    return SearchPage(
      count: found.length,
      results: List.unmodifiable(slice),
      hasNext: start + pageSize < found.length,
      cleanedQuery: q,
    );
  }

  @override
  Future<SearchPage> search(SearchQuery query, {int page = 1}) =>
      _page(query.q, query.zone, query.sector, page);

  @override
  Future<List<Suggestion>> suggestions(String q) async {
    final text = _plain(q.trim());
    if (text.length < kMinSuggestionChars) return const [];
    final out = <Suggestion>[];
    for (final s in _suggestions) {
      if (_plain(s.text).contains(text)) out.add(s);
    }
    return List.unmodifiable(out.take(kMaxSuggestions));
  }

  @override
  Future<SearchPage> voiceSearch(String text, {int? zone, String? sector, int page = 1}) {
    // Le serveur retire les mots de liaison (« je cherche du … à Maroua ») ; ici on en retire quelques-uns.
    const filler = {'je', 'cherche', 'du', 'de', 'la', 'le', 'les', 'des', 'a', 'au', 'un', 'une', 'pres', 'maroua'};
    final kept = _plain(text)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !filler.contains(w))
        .join(' ');
    return _page(kept, zone, sector, page);
  }

  static const _suggestions = [
    Suggestion(text: 'riz', type: SuggestionType.produit),
    Suggestion(text: 'riz local', type: SuggestionType.recherche),
    Suggestion(text: 'huile de palme', type: SuggestionType.produit),
    Suggestion(text: 'plombier', type: SuggestionType.recherche),
    Suggestion(text: 'poisson fumé', type: SuggestionType.produit),
    Suggestion(text: 'pharmacie', type: SuggestionType.recherche),
  ];

  // Zones du faux référentiel : 16 = Maroua ; 17 à 20 = ses quartiers.
  static const _demo = [
    SearchResult(
        id: 1, name: 'Boutique Aminatou', kind: 'produit', secteur: 'Alimentation',
        secteurCode: 'alimentation', zone: ResultZone(id: 17, name: 'Hardé'),
        repere: 'Près du marché', descriptionActivite: 'Riz, huile et condiments',
        prixIndicatif: 500, verifie: true),
    SearchResult(
        id: 2, name: 'Chez Mama Riz', kind: 'produit', secteur: 'Alimentation',
        secteurCode: 'alimentation', zone: ResultZone(id: 18, name: 'Dougoï'),
        repere: 'Face à la mosquée', descriptionActivite: 'Riz local en sacs', prixIndicatif: 18000),
    SearchResult(
        id: 3, name: 'Pharmacie du Centre', kind: 'produit', secteur: 'Santé',
        secteurCode: 'sante', zone: ResultZone(id: 19, name: 'Domayo'),
        descriptionActivite: 'Médicaments et conseils', verifie: true),
    SearchResult(
        id: 4, name: 'Plomberie Express', kind: 'service', secteur: 'Plomberie',
        zone: ResultZone(id: 16, name: 'Maroua'), descriptionActivite: 'Dépannage plomberie'),
    SearchResult(
        id: 5, name: 'Poissonnerie Djarengol', kind: 'produit', secteur: 'Alimentation',
        secteurCode: 'alimentation', zone: ResultZone(id: 20, name: 'Djarengol'),
        descriptionActivite: 'Poisson fumé et frais', prixIndicatif: 1500),
  ];
}
