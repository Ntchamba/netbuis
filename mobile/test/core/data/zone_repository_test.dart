import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/data/zones/zone.dart';
import 'package:netbuis/core/data/zones/zone_repository_api.dart';
import 'package:netbuis/core/data/zones/zone_repository_fake.dart';
import 'package:netbuis/core/network/api_exception.dart';

import 'recording_adapter.dart';

Map<String, Object?> _zone(int id, String name, String level,
        {int? parent, int order = 1}) =>
    {
      'id': id,
      'name': name,
      'level': level,
      'parent': parent,
      'official_code': '',
      'order': order,
      'latitude': null,
      'longitude': null,
    };

Map<String, Object?> _page(List<Object?> results, {String? next}) =>
    {'count': results.length, 'next': next, 'previous': null, 'results': results};

Matcher _code(ApiErrorCode c) =>
    throwsA(isA<ApiException>().having((e) => e.code, 'code', c));

void main() {
  group('ZoneRepositoryFake (zones.csv du serveur)', () {
    final repo = ZoneRepositoryFake();

    test('une seule ville : Maroua', () async {
      final cities = await repo.listZones(level: ZoneLevel.villeVillage);
      expect(cities.map((z) => z.name), ['Maroua']);
      expect(cities.single.level, ZoneLevel.villeVillage);
    });

    test('Cameroun, 10 régions, 3 arrondissements, 4 quartiers dans l\'ordre', () async {
      expect((await repo.listZones(level: ZoneLevel.pays)).map((z) => z.name), ['Cameroun']);
      final regions = await repo.listZones(level: ZoneLevel.region);
      expect(regions, hasLength(10));
      expect(regions.first.name, 'Adamaoua');
      expect(
        (await repo.listZones(level: ZoneLevel.arrondissement)).map((z) => z.name),
        ['Maroua 1', 'Maroua 2', 'Maroua 3'],
      );
      final maroua = (await repo.listZones(level: ZoneLevel.villeVillage)).single;
      final quartiers = await repo.listZones(level: ZoneLevel.quartier, parent: maroua.id);
      expect(quartiers.map((z) => z.name), ['Hardé', 'Dougoï', 'Domayo', 'Djarengol']);
    });

    test('détail : le chemin va du pays à la zone', () async {
      final maroua = (await repo.listZones(level: ZoneLevel.villeVillage)).single;
      final harde = (await repo.listZones(level: ZoneLevel.quartier, parent: maroua.id)).first;
      final detail = await repo.getZone(harde.id);
      expect(detail.zone.name, 'Hardé');
      expect(detail.path.map((p) => p.name),
          ['Cameroun', 'Extrême-Nord', 'Diamaré', 'Maroua', 'Hardé']);
      expect(detail.path.first.level, ZoneLevel.pays);
      expect(detail.path.last.id, harde.id);
    });

    test('zone inconnue : erreur 404', () async {
      await expectLater(
        repo.getZone(9999),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statut', 404)),
      );
    });
  });

  group('ZoneRepositoryApi', () {
    test('suit toutes les pages avec page_size=50 et le niveau demandé', () async {
      final adapter = RecordingAdapter((o) {
        final page = o.queryParameters['page'];
        if (page == 1) {
          return RecordingAdapter.ok(_page([_zone(1, 'Maroua', 'ville_village', parent: 12)],
              next: 'http://test/api/zones/?page=2'));
        }
        if (page == 2) {
          return RecordingAdapter.ok(_page([_zone(2, 'Garoua', 'ville_village', parent: 13)],
              next: 'http://test/api/zones/?page=3'));
        }
        return RecordingAdapter.ok(_page([_zone(3, 'Kousséri', 'ville_village', parent: 14)]));
      });
      final cities =
          await ZoneRepositoryApi(dioWith(adapter)).listZones(level: ZoneLevel.villeVillage);

      expect(cities.map((z) => z.name), ['Maroua', 'Garoua', 'Kousséri']);
      expect(adapter.seen, hasLength(3));
      for (final o in adapter.seen) {
        expect(o.path, '/zones/');
        expect(o.queryParameters['level'], 'ville_village');
        expect(o.queryParameters['page_size'], 50);
        expect(o.queryParameters.containsKey('parent'), isFalse);
      }
    });

    test('envoie le parent', () async {
      final adapter = RecordingAdapter((_) => RecordingAdapter.ok(_page([])));
      final zones = await ZoneRepositoryApi(dioWith(adapter))
          .listZones(level: ZoneLevel.quartier, parent: 16);
      expect(zones, isEmpty);
      expect(adapter.seen.single.queryParameters['parent'], 16);
      expect(adapter.seen.single.queryParameters['level'], 'quartier');
    });

    test('détail avec chemin', () async {
      final adapter = RecordingAdapter((_) => RecordingAdapter.ok({
            ..._zone(17, 'Hardé', 'quartier', parent: 16),
            'path': [
              {'id': 1, 'name': 'Cameroun', 'level': 'pays'},
              {'id': 17, 'name': 'Hardé', 'level': 'quartier'},
            ],
          }));
      final detail = await ZoneRepositoryApi(dioWith(adapter)).getZone(17);
      expect(adapter.seen.single.path, '/zones/17/');
      expect(detail.zone.parent, 16);
      expect(detail.path.map((p) => p.level), [ZoneLevel.pays, ZoneLevel.quartier]);
    });

    test('erreurs : 404, réseau coupé, réponse illisible, niveau inconnu', () async {
      final notFound = RecordingAdapter(
          (_) => (status: 404, body: {'code': 'not_found', 'message': 'x'}));
      await expectLater(
        ZoneRepositoryApi(dioWith(notFound)).getZone(1),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statut', 404)),
      );

      final cut = RecordingAdapter((o) => throw DioException(requestOptions: o));
      await expectLater(
          ZoneRepositoryApi(dioWith(cut)).listZones(), _code(ApiErrorCode.network));

      final garbage = RecordingAdapter((_) => RecordingAdapter.ok(['pas', 'une', 'page']));
      await expectLater(
          ZoneRepositoryApi(dioWith(garbage)).listZones(), _code(ApiErrorCode.unknown));

      final badLevel = RecordingAdapter(
          (_) => RecordingAdapter.ok(_page([_zone(1, 'X', 'galaxie')])));
      await expectLater(
          ZoneRepositoryApi(dioWith(badLevel)).listZones(), _code(ApiErrorCode.unknown));
    });

    test('une pagination sans fin s\'arrête avec une erreur', () async {
      final endless = RecordingAdapter((_) => RecordingAdapter.ok(
          _page([_zone(1, 'Maroua', 'ville_village')], next: 'http://test/api/zones/?page=2')));
      await expectLater(
          ZoneRepositoryApi(dioWith(endless)).listZones(), _code(ApiErrorCode.unknown));
      expect(endless.seen, hasLength(ZoneRepositoryApi.maxPages));
    });
  });
}
