import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/network/dio_client.dart';
import 'package:netbuis/features/auth/data/repositories/auth_repository_api.dart';

import 'auth_test_helpers.dart';

Matcher _code(ApiErrorCode c) =>
    throwsA(isA<ApiException>().having((e) => e.code, 'code', c));

AuthRepositoryApi _repo(FakeAdapter adapter, {String? access}) {
  final dio =
      buildDio(baseUrl: 'http://test/api', readAccessToken: () async => access);
  dio.httpClientAdapter = adapter;
  return AuthRepositoryApi(dio);
}

Map<String, Object?> _err(String code) => {'code': code, 'message': 'msg'};

void main() {
  test('délai de 15 s et base URL du client', () {
    final dio =
        buildDio(baseUrl: 'http://test/api', readAccessToken: () async => null);
    expect(dio.options.connectTimeout, const Duration(seconds: 15));
    expect(dio.options.receiveTimeout, const Duration(seconds: 15));
    expect(dio.options.baseUrl, 'http://test/api');
  });

  test('requestOtp : envoie le numéro et lit expires_in', () async {
    final adapter =
        FakeAdapter((_) => FakeAdapter.reply(202, {'expires_in': 300}));
    final r = await _repo(adapter).requestOtp('691234567');
    expect(r.expiresIn, const Duration(seconds: 300));
    expect(adapter.seen.single.path, '/auth/otp/request/');
    expect(adapter.seen.single.body, {'phone': '691234567'});
  });

  test('requestOtp : 400 invalid_phone, 429 avec Retry-After', () async {
    final bad =
        FakeAdapter((_) => FakeAdapter.reply(400, _err('invalid_phone')));
    await expectLater(
        _repo(bad).requestOtp('1'), _code(ApiErrorCode.invalidPhone));

    final many = FakeAdapter((_) => FakeAdapter.reply(
        429, _err('too_many_requests'),
        headers: {'retry-after': '120'}));
    await expectLater(
      _repo(many).requestOtp('691234567'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCode.tooManyRequests)
          .having(
              (e) => e.retryAfter, 'retryAfter', const Duration(seconds: 120))),
    );
  });

  test('requestOtp : réponse sans expires_in -> erreur inconnue', () async {
    final adapter =
        FakeAdapter((_) => FakeAdapter.reply(202, <String, Object?>{}));
    await expectLater(
        _repo(adapter).requestOtp('691234567'), _code(ApiErrorCode.unknown));
  });

  test('verifyOtp : lit access, refresh, is_new', () async {
    final adapter = FakeAdapter((_) => FakeAdapter.reply(
        200, {'access': 'a', 'refresh': 'r', 'is_new': true}));
    final t =
        await _repo(adapter).verifyOtp(phone: '691234567', code: '123456');
    expect((t.access, t.refresh, t.isNew), ('a', 'r', true));
    expect(adapter.seen.single.path, '/auth/otp/verify/');
    expect(adapter.seen.single.body, {'phone': '691234567', 'code': '123456'});
  });

  test(
      'verifyOtp : otp_invalid, otp_expired, too_many_requests, account_blocked, account_deleted',
      () async {
    final cases = {
      400: 'otp_invalid',
      400 + 1000: 'otp_expired',
      429: 'too_many_requests',
      403: 'account_blocked',
      403 + 1000: 'account_deleted',
    };
    final expected = {
      'otp_invalid': ApiErrorCode.otpInvalid,
      'otp_expired': ApiErrorCode.otpExpired,
      'too_many_requests': ApiErrorCode.tooManyRequests,
      'account_blocked': ApiErrorCode.accountBlocked,
      'account_deleted': ApiErrorCode.accountDeleted,
    };
    for (final entry in cases.entries) {
      final status = entry.key % 1000;
      final adapter =
          FakeAdapter((_) => FakeAdapter.reply(status, _err(entry.value)));
      await expectLater(
        _repo(adapter).verifyOtp(phone: '691234567', code: '111111'),
        _code(expected[entry.value]!),
        reason: entry.value,
      );
    }
  });

  test(
      'verifyOtp : réponse sans refresh -> erreur (pas de session à moitié créée)',
      () async {
    final adapter = FakeAdapter(
        (_) => FakeAdapter.reply(200, {'access': 'a', 'is_new': false}));
    await expectLater(
        _repo(adapter).verifyOtp(phone: '691234567', code: '123456'),
        _code(ApiErrorCode.unknown));
  });

  test('refresh : envoie {refresh} dans le corps et lit le NOUVEAU refresh',
      () async {
    final adapter = FakeAdapter(
        (_) => FakeAdapter.reply(200, {'access': 'a2', 'refresh': 'r2'}));
    final t = await _repo(adapter).refresh('r1');
    expect(adapter.seen.single.path, '/auth/refresh/');
    expect(adapter.seen.single.body, {'refresh': 'r1'});
    expect((t.access, t.refresh), ('a2', 'r2'));
  });

  test('refresh : 401 token_invalid ; 403 account_blocked', () async {
    final a = FakeAdapter((_) => FakeAdapter.reply(401, _err('token_invalid')));
    await expectLater(_repo(a).refresh('x'), _code(ApiErrorCode.tokenInvalid));
    final b =
        FakeAdapter((_) => FakeAdapter.reply(403, _err('account_blocked')));
    await expectLater(
        _repo(b).refresh('x'), _code(ApiErrorCode.accountBlocked));
  });

  test('logout : POST {refresh} -> 204 ; 401 token_invalid', () async {
    final ok = FakeAdapter((_) => FakeAdapter.reply(204, null));
    await _repo(ok).logout('r1');
    expect(ok.seen.single.path, '/auth/logout/');
    expect(ok.seen.single.body, {'refresh': 'r1'});
    final ko =
        FakeAdapter((_) => FakeAdapter.reply(401, _err('token_invalid')));
    await expectLater(_repo(ko).logout('r1'), _code(ApiErrorCode.tokenInvalid));
  });

  test('réseau coupé -> code network', () async {
    final adapter = FakeAdapter((r) => throw DioException(
        requestOptions: RequestOptions(path: r.path),
        type: DioExceptionType.connectionError));
    await expectLater(
        _repo(adapter).requestOtp('691234567'), _code(ApiErrorCode.network));
  });

  test('Authorization Bearer ajouté seulement quand un jeton d\'accès existe',
      () async {
    final with_ = FakeAdapter((_) => FakeAdapter.reply(204, null));
    await _repo(with_, access: 'tok').logout('r1');
    expect(with_.seen.single.headers['Authorization'], 'Bearer tok');
    final without = FakeAdapter((_) => FakeAdapter.reply(204, null));
    await _repo(without).logout('r1');
    expect(without.seen.single.headers.containsKey('Authorization'), isFalse);
  });
}
