import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/network/dio_client.dart';
import 'package:netbuis/features/business/data/models/business.dart';
import 'package:netbuis/features/business/data/repositories/business_repository_api.dart';
import 'package:netbuis/features/business/data/repositories/business_repository_fake.dart';

import '../auth/auth_test_helpers.dart';
import 'business_submit_helpers.dart';

BusinessRepositoryApi _repo(FakeAdapter main, FakeAdapter upload) {
  final dio = buildDio(baseUrl: kApiUrl, readAccessToken: () async => 'acc-test')
    ..httpClientAdapter = main;
  final up = buildUploadDio()..httpClientAdapter = upload;
  return BusinessRepositoryApi(dio, up, kApiUrl);
}

void main() {
  test('le client d\'envoi n\'a AUCUN intercepteur et les mêmes délais que le client principal', () {
    final up = buildUploadDio();
    // Dio garde un seul intercepteur interne (ImplyContentTypeInterceptor).
    expect(up.interceptors.map((i) => i.runtimeType.toString()),
        isNot(anyOf(contains('AuthInterceptor'), contains('RefreshInterceptor'))));
    final main = buildDio(baseUrl: kApiUrl, readAccessToken: () async => null);
    expect(up.options.connectTimeout, main.options.connectTimeout);
    expect(up.options.sendTimeout, main.options.sendTimeout);
    expect(up.options.receiveTimeout, main.options.receiveTimeout);
  });

  test('signUpload : corps {kind, content_type, size}, réponse lue', () async {
    final main = FakeAdapter((r) => FakeAdapter.reply(200, {
          'key': 'u1/photo/${'a' * 32}.jpg',
          'upload_url': '/api/uploads/local/t/',
          'method': 'PUT',
          'headers': {'Content-Type': 'image/jpeg'},
          'expires_in': 900,
        }));
    final repo = _repo(main, FakeAdapter((r) => FakeAdapter.reply(204, null)));
    final ticket =
        await repo.signUpload(kind: 'photo', contentType: 'image/jpeg', size: 42);
    expect(main.seen.single.path, '/uploads/sign/');
    expect(main.seen.single.body, {'kind': 'photo', 'content_type': 'image/jpeg', 'size': 42});
    expect(ticket.uploadUrl, '/api/uploads/local/t/');
    expect(ticket.headers, {'Content-Type': 'image/jpeg'});
    expect(ticket.expiresIn, 900);
  });

  test('signUpload : réponse mal formée ou méthode autre que PUT -> erreur inconnue', () async {
    for (final body in <Object?>[
      {'nope': 1},
      {'key': 'k', 'upload_url': '/x/', 'method': 'POST'},
      ['liste'],
    ]) {
      final repo = _repo(FakeAdapter((r) => FakeAdapter.reply(200, body)),
          FakeAdapter((r) => FakeAdapter.reply(204, null)));
      await expectLater(
        repo.signUpload(kind: 'photo', contentType: 'image/png', size: 1),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.unknown)),
      );
    }
  });

  test('putFile : EXACTEMENT les en-têtes du serveur (même inhabituels), aucun Authorization',
      () async {
    final upload = FakeAdapter((r) => FakeAdapter.reply(204, null));
    final main = FakeAdapter((r) => FakeAdapter.reply(500, {}));
    final repo = _repo(main, upload);
    const ticket = UploadTicket(
      key: 'u1/photo/x.jpg',
      uploadUrl: 'https://seau.example.test/u1/photo/x.jpg?sig=1',
      headers: {'Content-Type': 'image/jpeg', 'x-amz-acl': 'private'},
    );
    final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3]);
    await repo.putFile(ticket, bytes);

    expect(main.seen, isEmpty, reason: 'le client authentifié n\'est pas utilisé');
    final put = upload.seen.single;
    expect(put.method, 'PUT');
    expect(put.path, 'https://seau.example.test/u1/photo/x.jpg?sig=1');
    expect(put.body, bytes);
    final names = put.headers.keys.map((k) => k.toLowerCase()).toSet();
    expect(names, {'content-type', 'x-amz-acl', 'content-length'});
    expect(put.headers['x-amz-acl'], 'private');
    expect(put.headers['content-length'], '6');
  });

  test('putFile : une adresse inutilisable est refusée AVANT tout envoi', () async {
    final upload = FakeAdapter((r) => FakeAdapter.reply(204, null));
    final repo = _repo(FakeAdapter((r) => FakeAdapter.reply(500, {})), upload);
    await expectLater(
      repo.putFile(
          const UploadTicket(key: 'k', uploadUrl: 'pas-une-adresse', headers: {}), Uint8List(1)),
      throwsA(isA<ApiException>()),
    );
    expect(upload.seen, isEmpty);
  });

  test('putFile : 403 / 400 / 413 deviennent des ApiException avec le code du serveur', () async {
    for (final (status, code) in [
      (403, 'already_used'),
      (403, 'invalid_token'),
      (400, 'invalid_content'),
      (413, 'too_large'),
    ]) {
      final repo = _repo(FakeAdapter((r) => FakeAdapter.reply(500, {})),
          FakeAdapter((r) => FakeAdapter.reply(status, {'code': code, 'message': 'brut'})));
      await expectLater(
        repo.putFile(
            const UploadTicket(key: 'k', uploadUrl: '/api/uploads/local/t/', headers: {}),
            Uint8List(1)),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statut', status)
            .having((e) => e.serverCode, 'code', code)),
      );
    }
  });

  test('create : POST /business/ ; getMine : statut et motif lus', () async {
    final main = FakeAdapter((r) => r.method == 'POST'
        ? FakeAdapter.reply(201, {'id': 1, 'name': 'X', 'status': 'en_attente_validation'})
        : FakeAdapter.reply(200, {
            'id': 1,
            'name': 'X',
            'status': 'rejete',
            'motif_rejet': 'Photo floue',
            'phone_masked': '+237 6•• •• •• 12',
          }));
    final repo = _repo(main, FakeAdapter((r) => FakeAdapter.reply(204, null)));
    final created = await repo.create({'name': 'X'});
    expect(created.status, BusinessStatus.pending);
    expect(main.seen.first.path, '/business/');
    expect(main.seen.first.body, {'name': 'X'});
    final mine = await repo.getMine();
    expect(mine.status, BusinessStatus.rejected);
    expect(mine.motifRejet, 'Photo floue');
    expect(main.seen.last.path, '/business/me/');
  });

  test('getMine : 404 no_business et statut inconnu', () async {
    var repo = _repo(
        FakeAdapter((r) => FakeAdapter.reply(404, {'code': 'no_business', 'message': 'x'})),
        FakeAdapter((r) => FakeAdapter.reply(204, null)));
    await expectLater(
        repo.getMine(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statut', 404)
            .having((e) => e.serverCode, 'code', ServerCodes.noBusiness)));

    repo = _repo(FakeAdapter((r) => FakeAdapter.reply(200, {'status': 'inconnu'})),
        FakeAdapter((r) => FakeAdapter.reply(204, null)));
    await expectLater(repo.getMine(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.unknown)));
  });

  test('coupure réseau : ApiErrorCode.network', () async {
    final repo = _repo(
        FakeAdapter((r) => throw DioException(
            requestOptions: RequestOptions(path: r.path), type: DioExceptionType.connectionError)),
        FakeAdapter((r) => FakeAdapter.reply(204, null)));
    await expectLater(repo.getMine(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.network)));
  });

  group('faux dépôt', () {
    test('accepte tout, garde l\'état en mémoire, ne contacte aucun réseau', () async {
      var created = 0;
      final repo = BusinessRepositoryFake(onCreated: () => created++);
      await expectLater(repo.getMine(), throwsA(isA<ApiException>()));
      final t = await repo.signUpload(kind: 'cni_photo', contentType: 'image/png', size: 3);
      expect(t.key, startsWith('fictif/'));
      await repo.putFile(t, Uint8List(3));
      final mine = await repo.create({'name': 'Ma boutique'});
      expect(mine.status, BusinessStatus.pending);
      expect((await repo.getMine()).name, 'Ma boutique');
      expect(created, 1);
      await expectLater(
          repo.create({}), throwsA(isA<ApiException>().having((e) => e.statusCode, 's', 409)));
    });
  });
}
