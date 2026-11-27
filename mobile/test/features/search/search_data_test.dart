import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/network/dio_client.dart';
import 'package:netbuis/features/search/data/models/search_query.dart';
import 'package:netbuis/features/search/data/models/search_result.dart';
import 'package:netbuis/features/search/data/models/suggestion.dart';
import 'package:netbuis/features/search/data/repositories/search_repository_api.dart';
import 'package:netbuis/features/search/data/repositories/search_repository_fake.dart';

import '../auth/auth_test_helpers.dart';
import '../business/business_submit_helpers.dart';

Map<String, Object?> _json(int id, {Object? price = 500}) => {
      'id': id,
      'name': 'Commerce $id',
      'kind': 'produit',
      'secteur': 'Alimentation',
      'secteur_code': 'alimentation',
      'zone': {'id': 17, 'name': 'Hardé'},
      'repere': 'Près du marché',
      'description_activite': 'Riz',
      'photo': null,
      'prix_indicatif': price,
      'verifie': true,
    };

Map<String, Object?> _page(List<Object?> results, {String? next, String? q}) => {
      'count': results.length,
      'next': next,
      'previous': null,
      if (q != null) 'q': q,
      'results': results,
    };

SearchRepositoryApi _repo(FakeAdapter adapter) => SearchRepositoryApi(
    buildDio(baseUrl: kApiUrl, readAccessToken: () async => 'acc-test')..httpClientAdapter = adapter);

void main() {
  group('modèles', () {
    test('SearchResult.fromJson : champs du contrat, null = sur demande', () {
      final r = SearchResult.fromJson(_json(1));
      expect(r.name, 'Commerce 1');
      expect(r.zone, const ResultZone(id: 17, name: 'Hardé'));
      expect(r.prixIndicatif, 500);
      expect(r.verifie, isTrue);
      expect(SearchResult.fromJson(_json(2, price: null)).prixIndicatif, isNull);
    });

    test('SearchResult.fromJson : réponse mal formée -> FormatException', () {
      expect(() => SearchResult.fromJson({'id': 'x'}), throwsFormatException);
      expect(() => SearchResult.fromJson(_json(1, price: 'cher')), throwsFormatException);
    });

    test('Suggestion.fromJson refuse un type inconnu', () {
      expect(Suggestion.fromJson({'text': 'riz', 'type': 'produit'}).type, SuggestionType.produit);
      expect(() => Suggestion.fromJson({'text': 'riz', 'type': 'autre'}), throwsFormatException);
    });

    test('SearchQuery.toParams ne garde que les paramètres utiles', () {
      expect(const SearchQuery().toParams(1), {'page': 1});
      expect(const SearchQuery(q: ' riz ', zone: 16, sector: 'alimentation').toParams(2),
          {'q': 'riz', 'zone': 16, 'sector': 'alimentation', 'page': 2});
    });
  });

  group('dépôt api', () {
    test('search envoie q, zone, sector, page et lit la page', () async {
      final adapter = FakeAdapter((r) => FakeAdapter.reply(
          200, _page([_json(1), _json(2)], next: 'http://x/api/search/?page=2')));
      final page = await _repo(adapter)
          .search(const SearchQuery(q: 'riz', zone: 16, sector: 'alimentation'), page: 1);
      expect(page.results.map((r) => r.id), [1, 2]);
      expect(page.hasNext, isTrue);
      expect(adapter.seen.single.method, 'GET');
      expect(adapter.seen.single.path, contains('/search/'));
    });

    test('search : 403 account_blocked -> ApiException typée', () async {
      final adapter = FakeAdapter((r) => FakeAdapter.reply(
          403, {'code': 'account_blocked', 'message': 'Compte bloqué'}));
      expect(
        _repo(adapter).search(const SearchQuery()),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.accountBlocked)),
      );
    });

    test('search : réponse illisible -> ApiException unknown', () async {
      final adapter = FakeAdapter((r) => FakeAdapter.reply(200, {'results': 'x'}));
      expect(
        _repo(adapter).search(const SearchQuery()),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.unknown)),
      );
    });

    test('suggestions : moins de 2 caractères -> aucun appel ; 8 au plus', () async {
      final adapter = FakeAdapter((r) => FakeAdapter.reply(200, [
            for (var i = 0; i < 12; i++) {'text': 'riz $i', 'type': 'recherche'},
          ]));
      final repo = _repo(adapter);
      expect(await repo.suggestions('r'), isEmpty);
      expect(adapter.seen, isEmpty);
      final found = await repo.suggestions('ri');
      expect(found, hasLength(kMaxSuggestions));
      expect(adapter.seen, hasLength(1));
    });

    test('voiceSearch : POST {text, zone, sector} et lit q nettoyé', () async {
      final adapter =
          FakeAdapter((r) => FakeAdapter.reply(200, _page([_json(1)], q: 'riz')));
      final page = await _repo(adapter)
          .voiceSearch('je cherche du riz à Akwa', zone: 16, sector: 'alimentation');
      expect(page.cleanedQuery, 'riz');
      final sent = adapter.seen.single;
      expect(sent.method, 'POST');
      expect(sent.path, contains('/search/voice/'));
      expect(sent.body, {'text': 'je cherche du riz à Akwa', 'zone': 16, 'sector': 'alimentation'});
    });

    test('voiceSearch : texte coupé à 300 caractères', () async {
      final adapter = FakeAdapter((r) => FakeAdapter.reply(200, _page([])));
      await _repo(adapter).voiceSearch('a' * 400);
      expect(((adapter.seen.single.body as Map)['text'] as String).length, 300);
    });
  });

  group('dépôt fake', () {
    test('q vide : tous les commerces ; q : filtre sans tenir compte des accents', () async {
      final repo = SearchRepositoryFake();
      expect((await repo.search(const SearchQuery())).count, 5);
      final found = await repo.search(const SearchQuery(q: 'sante'));
      expect(found.results.single.name, 'Pharmacie du Centre');
      expect((await repo.search(const SearchQuery(q: 'zzzz'))).results, isEmpty);
    });

    test('zone : inclut les quartiers de la ville ; zone inconnue -> 400', () async {
      final repo = SearchRepositoryFake();
      expect((await repo.search(const SearchQuery(zone: 16))).count, 5);
      expect((await repo.search(const SearchQuery(zone: 17))).count, 1);
      expect(
        repo.search(const SearchQuery(zone: 9999)),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
      );
    });

    test('pagination : pages de taille fixe, hasNext puis fin', () async {
      final repo = SearchRepositoryFake(pageSize: 2);
      final p1 = await repo.search(const SearchQuery());
      final p3 = await repo.search(const SearchQuery(), page: 3);
      expect(p1.results, hasLength(2));
      expect(p1.hasNext, isTrue);
      expect(p3.results, hasLength(1));
      expect(p3.hasNext, isFalse);
    });

    test('suggestions : <2 caractères vide, sinon correspondances', () async {
      final repo = SearchRepositoryFake();
      expect(await repo.suggestions('r'), isEmpty);
      expect((await repo.suggestions('riz')).map((s) => s.text), ['riz', 'riz local']);
    });

    test('voiceSearch : retire les mots de liaison', () async {
      final page = await SearchRepositoryFake().voiceSearch('je cherche du riz à Maroua');
      expect(page.cleanedQuery, 'riz');
      expect(page.results.map((r) => r.id), [1, 2]);
    });
  });
}
