import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/data/referentials/referential_repository_api.dart';
import 'package:netbuis/core/data/referentials/referential_repository_fake.dart';
import 'package:netbuis/core/network/api_exception.dart';

import 'recording_adapter.dart';

Matcher _code(ApiErrorCode c) =>
    throwsA(isA<ApiException>().having((e) => e.code, 'code', c));

void main() {
  group('ReferentialRepositoryFake (categories.json du serveur)', () {
    const repo = ReferentialRepositoryFake();

    test('10 secteurs dans l\'ordre, avec icône et sous-catégories', () async {
      final sectors = await repo.getSectors();
      expect(sectors, hasLength(10));
      expect(sectors.first.name, 'Alimentation');
      expect(sectors.first.icon, '🍌');
      expect(sectors.first.code, 'alimentation');
      expect(sectors.first.subcategories, hasLength(12));
      expect(sectors.first.subcategories.first.name, 'Fruits');
      expect(sectors.last.name, 'Autre');
      expect([for (final s in sectors) s.order], [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final artisanat = sectors.firstWhere((s) => s.code == 'artisanat_services_domicile');
      expect(artisanat.subcategories, hasLength(9));
      expect(artisanat.subcategories.last.code, 'autre');
    });

    test('identifiants uniques', () async {
      final sectors = await repo.getSectors();
      expect({for (final s in sectors) s.id}, hasLength(10));
      final subs = [for (final s in sectors) ...s.subcategories];
      expect({for (final s in subs) s.id}, hasLength(subs.length));
    });

    test('7 catégories de service et 5 types de structure', () async {
      final services = await repo.getServiceCategories();
      expect(services, hasLength(7));
      expect(services.first.name, 'Enseignement à domicile');
      expect(services.last.name, 'Autre');
      final types = await repo.getStructureTypes();
      expect(types.map((t) => t.name),
          ['Supermarché', 'Restaurant', 'Hôtel', 'Centre de santé', 'Autre']);
      expect(types.first.icon, '🛒');
    });

    test('catalogue vide : aucun produit inventé ; recherche vide refusée', () async {
      expect(await repo.searchProducts('riz'), isEmpty);
      await expectLater(repo.searchProducts('  '), _code(ApiErrorCode.invalid));
      await expectLater(repo.searchProducts('a' * 101), _code(ApiErrorCode.invalid));
    });
  });

  group('ReferentialRepositoryApi', () {
    test('secteurs avec sous-catégories', () async {
      final adapter = RecordingAdapter((_) => RecordingAdapter.ok([
            {
              'id': 3,
              'code': 'alimentation',
              'name': 'Alimentation',
              'icon': '🍌',
              'order': 1,
              'subcategories': [
                {'id': 8, 'code': 'fruits', 'name': 'Fruits', 'icon': '', 'order': 1},
              ],
            },
          ]));
      final sectors = await ReferentialRepositoryApi(dioWith(adapter)).getSectors();
      expect(adapter.seen.single.path, '/referentials/sectors/');
      expect(sectors.single.id, 3);
      expect(sectors.single.subcategories.single.code, 'fruits');
    });

    test('catégories de service et types de structure : bons chemins', () async {
      final adapter = RecordingAdapter((_) => RecordingAdapter.ok([
            {'id': 1, 'code': 'autre', 'name': 'Autre', 'icon': '', 'order': 1},
          ]));
      final repo = ReferentialRepositoryApi(dioWith(adapter));
      expect((await repo.getServiceCategories()).single.code, 'autre');
      expect((await repo.getStructureTypes()).single.name, 'Autre');
      expect(adapter.seen.map((o) => o.path),
          ['/referentials/service-categories/', '/referentials/structure-types/']);
    });

    test('produits : envoie q ; renvoie les champs du contrat', () async {
      final adapter = RecordingAdapter((_) => RecordingAdapter.ok([
            {'id': 5, 'name': 'Riz', 'sector': 'alimentation', 'subcategory': null},
          ]));
      final products =
          await ReferentialRepositoryApi(dioWith(adapter)).searchProducts(' riz ');
      expect(adapter.seen.single.path, '/catalog/products/');
      expect(adapter.seen.single.queryParameters, {'q': 'riz'});
      expect(products.single.name, 'Riz');
      expect(products.single.sector, 'alimentation');
      expect(products.single.subcategory, isNull);
    });

    test('produits : q vide ou trop long refusé sans appel réseau', () async {
      final adapter = RecordingAdapter((_) => RecordingAdapter.ok([]));
      final repo = ReferentialRepositoryApi(dioWith(adapter));
      await expectLater(repo.searchProducts(''), _code(ApiErrorCode.invalid));
      await expectLater(repo.searchProducts('a' * 101), _code(ApiErrorCode.invalid));
      expect(adapter.seen, isEmpty);
    });

    test('erreurs : 400 du serveur, réseau coupé, réponse illisible', () async {
      final bad = RecordingAdapter(
          (_) => (status: 400, body: {'code': 'invalid', 'message': 'q'}));
      await expectLater(
          ReferentialRepositoryApi(dioWith(bad)).searchProducts('riz'),
          _code(ApiErrorCode.invalid));

      final cut = RecordingAdapter((o) => throw DioException(requestOptions: o));
      await expectLater(
          ReferentialRepositoryApi(dioWith(cut)).getSectors(), _code(ApiErrorCode.network));

      final garbage = RecordingAdapter((_) => RecordingAdapter.ok({'results': []}));
      await expectLater(
          ReferentialRepositoryApi(dioWith(garbage)).getStructureTypes(),
          _code(ApiErrorCode.unknown));

      final noSubs = RecordingAdapter((_) => RecordingAdapter.ok([
            {'id': 1, 'code': 'a', 'name': 'A', 'icon': '', 'order': 1},
          ]));
      await expectLater(
          ReferentialRepositoryApi(dioWith(noSubs)).getSectors(), _code(ApiErrorCode.unknown));
    });
  });
}
