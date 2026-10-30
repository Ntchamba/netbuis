import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/network/dio_client.dart';
import 'package:netbuis/features/account/data/models/me.dart';
import 'package:netbuis/features/account/data/repositories/account_repository_api.dart';
import 'package:netbuis/features/account/data/repositories/account_repository_fake.dart';

import '../auth/auth_test_helpers.dart';

const _meJson = {
  'id': 7,
  'name': 'Jeff N.',
  'phone_masked': '+237 6•• •• •• 12',
  'language': 'fr',
  'has_business': false,
  'free_call_available': null,
  'credits_balance': null,
};

AccountRepositoryApi _api(FakeAdapter adapter) {
  final dio = buildDio(
      baseUrl: 'http://test/api', readAccessToken: () async => 'acc-test');
  dio.httpClientAdapter = adapter;
  return AccountRepositoryApi(dio);
}

void main() {
  group('Me', () {
    test('lit la réponse du contrat (null accepté pour les crédits)', () {
      final me = Me.fromJson(_meJson);
      expect((me.id, me.name, me.phoneMasked, me.language),
          (7, 'Jeff N.', '+237 6•• •• •• 12', 'fr'));
      expect((me.freeCallAvailable, me.creditsBalance, me.hasBusiness),
          (null, null, false));
    });

    test('un nom absent ou nul donne un nom vide', () {
      final json = {..._meJson}..remove('name');
      expect(Me.fromJson(json).hasName, isFalse);
      expect(Me.fromJson({..._meJson, 'name': null}).hasName, isFalse);
    });

    test('une réponse sans numéro masqué est refusée', () {
      expect(() => Me.fromJson({'id': 1}), throwsFormatException);
    });
  });

  group('initiales et nom', () {
    test('deux lettres au plus, en majuscules', () {
      expect(initialsOf('Jeff N.'), 'JN');
      expect(initialsOf('jeff'), 'J');
      expect(initialsOf('  marie  claire  ndongo '), 'MC');
      expect(initialsOf('élodie'), 'É');
    });

    test('sans lettre : aucune initiale (jamais de chiffres)', () {
      expect(initialsOf(''), '');
      expect(initialsOf('612 345'), '');
    });

    test('cleanName retire les espaces ; vide = rien à envoyer', () {
      expect(cleanName('  Jeff  '), 'Jeff');
      expect(cleanName('   '), isNull);
      expect(cleanName(''), isNull);
    });
  });

  group('AccountRepositoryApi', () {
    test('GET /me/ avec le jeton Bearer', () async {
      final adapter = FakeAdapter((r) => FakeAdapter.reply(200, _meJson));
      final me = await _api(adapter).getMe();
      expect(me.name, 'Jeff N.');
      expect(adapter.seen.single.method, 'GET');
      expect(adapter.seen.single.path, '/me/');
      expect(adapter.seen.single.headers['Authorization'], 'Bearer acc-test');
    });

    test('PATCH /me/ n\'envoie que le nom', () async {
      final adapter = FakeAdapter((r) => FakeAdapter.reply(200, _meJson));
      await _api(adapter).updateName('Jeff N.');
      expect(adapter.seen.single.method, 'PATCH');
      expect(adapter.seen.single.body, {'name': 'Jeff N.'});
    });

    test('DELETE /me/ : 204 accepté, avec le jeton Bearer', () async {
      final adapter = FakeAdapter((r) => FakeAdapter.reply(204, null));
      await _api(adapter).deleteAccount();
      expect(adapter.seen.single.method, 'DELETE');
      expect(adapter.seen.single.path, '/me/');
      expect(adapter.seen.single.headers['Authorization'], 'Bearer acc-test');
    });

    test('DELETE /me/ : réseau coupé = erreur network ; 403 = compte bloqué', () async {
      final down = FakeAdapter((r) => throw DioException(
          requestOptions: RequestOptions(path: '/me/'),
          type: DioExceptionType.connectionError));
      await expectLater(
          _api(down).deleteAccount(),
          throwsA(isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.network)));
      final blocked = FakeAdapter(
          (r) => FakeAdapter.reply(403, {'code': 'account_blocked', 'message': ''}));
      await expectLater(
          _api(blocked).deleteAccount(),
          throwsA(isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.accountBlocked)));
    });

    test('401 : erreur typée avec le statut', () async {
      final adapter = FakeAdapter((r) =>
          FakeAdapter.reply(401, {'code': 'token_not_valid', 'message': 'x'}));
      await expectLater(
        _api(adapter).getMe(),
        throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('403 compte bloqué et 400 nom invalide', () async {
      var status = 403;
      final adapter = FakeAdapter((r) => FakeAdapter.reply(status, {
            'code': status == 403 ? 'account_blocked' : 'invalid',
            'message': ''
          }));
      final api = _api(adapter);
      await expectLater(
          api.getMe(),
          throwsA(isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.accountBlocked)));
      status = 400;
      await expectLater(
          api.updateName('x'),
          throwsA(isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.invalid)));
    });

    test('réponse illisible : erreur inconnue', () async {
      final adapter =
          FakeAdapter((r) => FakeAdapter.reply(200, {'oops': true}));
      await expectLater(
          _api(adapter).getMe(),
          throwsA(isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.unknown)));
    });

    test('réseau coupé : code network', () async {
      final adapter = FakeAdapter((r) => throw DioException(
          requestOptions: RequestOptions(path: '/me/'),
          type: DioExceptionType.connectionError));
      await expectLater(
          _api(adapter).getMe(),
          throwsA(isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.network)));
    });
  });

  group('AccountRepositoryFake', () {
    test('numéro masqué fictif et nom gardé en mémoire', () async {
      final repo = AccountRepositoryFake();
      final first = await repo.getMe();
      expect(first.phoneMasked, '+237 6•• •• •• 12');
      expect(first.hasName, isFalse);
      await repo.updateName('  Jeff N. ');
      expect((await repo.getMe()).name, 'Jeff N.');
    });

    test('un nom vide ou trop long est refusé', () async {
      final repo = AccountRepositoryFake();
      await expectLater(repo.updateName('  '), throwsA(isA<ApiException>()));
      await expectLater(
          repo.updateName('a' * 121), throwsA(isA<ApiException>()));
      await repo.updateName('a' * 120);
    });
  });
}
