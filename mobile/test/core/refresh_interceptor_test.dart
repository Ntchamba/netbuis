import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/guards.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/auth/application/auth_controller.dart';
import 'package:netbuis/features/auth/application/auth_state.dart';
import 'package:netbuis/features/auth/data/repositories/auth_repository_api.dart';

import '../features/auth/auth_test_helpers.dart';

typedef _Reply = ({int status, Object? body, Map<String, String> headers});

/// Faux serveur : `/me/` n'accepte que l'accès `good`; `/auth/refresh/` suit [onRefresh].
class _Server {
  _Server({this.onRefresh});
  String good = 'acc-new';
  _Reply Function(SeenRequest)? onRefresh;
  int refreshCalls = 0;

  _Reply handle(SeenRequest r) {
    if (r.path == '/auth/refresh/') {
      refreshCalls++;
      return onRefresh != null
          ? onRefresh!(r)
          : FakeAdapter.reply(200, {'access': 'acc-new', 'refresh': 'ref-new'});
    }
    return r.headers['Authorization'] == 'Bearer $good'
        ? FakeAdapter.reply(200, {'ok': true})
        : FakeAdapter.reply(401, {'code': 'token_invalid', 'message': 'x'});
  }
}

class _Rig {
  _Rig(this.server, {String? access = 'acc-old', String? refresh = 'ref-old'})
      : storage = MemoryTokenStorage(access: access, refresh: refresh) {
    adapter = FakeAdapter(server.handle);
    container = ProviderContainer(overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider
          .overrideWith((ref) => AuthRepositoryApi(ref.read(dioProvider))),
    ]);
    addTearDown(container.dispose);
    dio = container.read(dioProvider)..httpClientAdapter = adapter;
    container.listen(authControllerProvider, (_, __) {});
  }
  final _Server server;
  final MemoryTokenStorage storage;
  late final FakeAdapter adapter;
  late final ProviderContainer container;
  late final Dio dio;

  AuthState get auth => container.read(authControllerProvider);
  int count(String path) => adapter.seen.where((r) => r.path == path).length;
}

Matcher _api(ApiErrorCode c) => throwsA(
    isA<DioException>().having((e) => ApiException.fromDio(e).code, 'code', c));

void main() {
  test(
      '401 : un seul renouvellement, nouveau couple enregistré, requête rejouée une fois',
      () async {
    final rig = _Rig(_Server());
    final r = await rig.dio.get<Object?>('/me/');
    expect(r.statusCode, 200);
    expect(rig.server.refreshCalls, 1);
    expect(rig.count('/me/'), 2);
    expect(rig.adapter.seen.last.headers['Authorization'], 'Bearer acc-new');
    expect(rig.adapter.seen.last.headers.containsKey('Authorization'), isTrue);
    final stored = await rig.storage.read();
    expect((stored.access, stored.refresh), ('acc-new', 'ref-new'));
    expect(rig.adapter.seen.firstWhere((s) => s.path == '/auth/refresh/').body,
        {'refresh': 'ref-old'});
  });

  test('requête rejouée : mêmes méthode, chemin et corps', () async {
    final rig = _Rig(_Server());
    await rig.dio.post<Object?>('/me/', data: {'name': 'Ann'});
    final posts = rig.adapter.seen.where((s) => s.path == '/me/').toList();
    expect(posts.map((s) => s.method), ['POST', 'POST']);
    expect(posts.map((s) => s.body), [
      {'name': 'Ann'},
      {'name': 'Ann'}
    ]);
  });

  test('sans 401 : aucun renouvellement', () async {
    final server = _Server()..good = 'acc-old';
    final rig = _Rig(server);
    await rig.dio.get<Object?>('/me/');
    expect(server.refreshCalls, 0);
  });

  test(
      'plusieurs 401 simultanés : un seul appel de renouvellement, tous rejoués',
      () async {
    final rig = _Rig(_Server());
    final results = await Future.wait([
      rig.dio.get<Object?>('/me/'),
      rig.dio.get<Object?>('/me/'),
      rig.dio.get<Object?>('/me/'),
    ]);
    expect(results.map((r) => r.statusCode), [200, 200, 200]);
    expect(rig.server.refreshCalls, 1);
    expect(rig.count('/me/'), 6);
  });

  test(
      'requête en vol avec l\'ancien accès après un renouvellement : rejouée sans 2e renouvellement',
      () async {
    final rig = _Rig(_Server());
    await rig.dio.get<Object?>('/me/'); // renouvelle une fois
    // Requête partie avec l'ancien accès, 401 arrivé après le renouvellement.
    final r = await rig.dio.get<Object?>('/me/',
        options: Options(headers: {'Authorization': 'Bearer acc-old'}));
    expect(r.statusCode, 200);
    expect(rig.server.refreshCalls, 1);
  });

  test('pas de boucle : 401 sur la requête rejouée -> pas de 2e renouvellement',
      () async {
    final server = _Server()..good = 'jamais';
    final rig = _Rig(server);
    await expectLater(
        rig.dio.get<Object?>('/me/'), _api(ApiErrorCode.tokenInvalid));
    expect(server.refreshCalls, 1);
    expect(rig.count('/me/'), 2);
  });

  test('routes d\'authentification : 401 ne déclenche jamais de renouvellement',
      () async {
    for (final path in [
      '/auth/otp/request/',
      '/auth/otp/verify/',
      '/auth/logout/'
    ]) {
      final server = _Server();
      final rig = _Rig(server);
      rig.adapter.seen.clear();
      final adapter = FakeAdapter((r) =>
          FakeAdapter.reply(401, {'code': 'token_invalid', 'message': ''}));
      rig.dio.httpClientAdapter = adapter;
      await expectLater(rig.dio.post<Object?>(path, data: {}),
          _api(ApiErrorCode.tokenInvalid));
      expect(adapter.seen.map((s) => s.path), [path], reason: path);
    }
  });

  test('/auth/refresh/ lui-même en 401 : pas de renouvellement récursif',
      () async {
    final server = _Server(
        onRefresh: (_) =>
            FakeAdapter.reply(401, {'code': 'token_invalid', 'message': ''}));
    final rig = _Rig(server);
    await expectLater(
        rig.dio.get<Object?>('/me/'), _api(ApiErrorCode.tokenInvalid));
    expect(server.refreshCalls, 1);
  });

  test(
      'renouvellement refusé (token_invalid) : jetons effacés, non connecté, garde -> /login',
      () async {
    final rig = _Rig(_Server(
        onRefresh: (_) =>
            FakeAdapter.reply(401, {'code': 'token_invalid', 'message': ''})));
    await rig.container.read(authControllerProvider.notifier).restoreSession();
    expect(rig.auth, isA<AuthAuthenticated>());
    await expectLater(
        rig.dio.get<Object?>('/me/'), throwsA(isA<DioException>()));
    final stored = await rig.storage.read();
    expect((stored.access, stored.refresh), (null, null));
    expect(rig.auth, isA<AuthLoggedOut>());
    expect(authRedirect(rig.auth, Routes.home), Routes.login);
    expect(rig.count('/me/'), 1);
  });

  for (final (code, status) in [
    ('account_blocked', 403),
    ('account_deleted', 403)
  ]) {
    test('renouvellement refusé ($code) : jetons effacés et erreur de compte',
        () async {
      final rig = _Rig(_Server(
          onRefresh: (_) =>
              FakeAdapter.reply(status, {'code': code, 'message': ''})));
      await rig.container
          .read(authControllerProvider.notifier)
          .restoreSession();
      await expectLater(
          rig.dio.get<Object?>('/me/'), throwsA(isA<DioException>()));
      expect((await rig.storage.read()).hasRefresh, isFalse);
      final s = rig.auth;
      expect(s, isA<AuthFailure>());
      expect((s as AuthFailure).code, ApiErrorCode.fromValue(code));
      expect(authRedirect(s, Routes.home), Routes.login);
    });
  }

  test(
      'réseau coupé pendant le renouvellement : session conservée, erreur réseau',
      () async {
    final rig = _Rig(_Server());
    rig.dio.httpClientAdapter = FakeAdapter((r) {
      if (r.path == '/auth/refresh/') {
        throw DioException(
            requestOptions: RequestOptions(path: r.path),
            type: DioExceptionType.connectionError);
      }
      return FakeAdapter.reply(401, {'code': 'token_invalid', 'message': ''});
    });
    await rig.container.read(authControllerProvider.notifier).restoreSession();
    await expectLater(rig.dio.get<Object?>('/me/'), _api(ApiErrorCode.network));
    final stored = await rig.storage.read();
    expect((stored.access, stored.refresh), ('acc-old', 'ref-old'));
    expect(rig.auth, isA<AuthAuthenticated>());
  });

  test('aucun jeton dans les messages d\'erreur', () async {
    final server = _Server()..good = 'jamais';
    final rig = _Rig(server);
    try {
      await rig.dio.get<Object?>('/me/');
      fail('doit échouer');
    } on DioException catch (e) {
      final text =
          ApiException.fromDio(e).toString() + ApiException.fromDio(e).message;
      for (final t in ['acc-old', 'acc-new', 'ref-old', 'ref-new']) {
        expect(text.contains(t), isFalse, reason: t);
      }
    }
  });
}
