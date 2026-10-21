import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/network/dio_client.dart';
import 'package:netbuis/features/call/data/call_channel.dart';
import 'package:netbuis/features/call/data/models/call_session.dart';
import 'package:netbuis/features/call/data/repositories/call_repository_api.dart';
import 'package:netbuis/features/call/data/repositories/call_repository_fake.dart';

import '../auth/auth_test_helpers.dart';
import '../business/business_submit_helpers.dart' show kApiUrl;
import 'call_test_helpers.dart' show kFakeDigits, kFakePhone;

CallRepositoryApi _repo(FakeAdapter a) => CallRepositoryApi(
    buildDio(baseUrl: kApiUrl, readAccessToken: () async => 'acc-test')..httpClientAdapter = a);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('POST /calls/initiate/', () {
    test('corps {business_id, channel=call, platform=android, operator} et réponse lue', () async {
      final a = FakeAdapter((r) => FakeAdapter.reply(200, {'call_id': 12, 'phone': kFakePhone}));
      final s = await _repo(a).initiate(businessId: 5, line: CallLine.mtn);
      expect(a.seen.single.method, 'POST');
      expect(a.seen.single.path, '/calls/initiate/');
      expect(a.seen.single.body,
          {'business_id': 5, 'channel': 'call', 'platform': 'android', 'operator': 'mtn'});
      expect(s.callId, 12);
      expect(s.phone, kFakePhone);
      expect(s.toString(), isNot(contains(kFakeDigits)));
    });

    test('ligne inconnue : pas de champ operator', () async {
      final a = FakeAdapter((r) => FakeAdapter.reply(200, {'call_id': 1, 'phone': kFakePhone}));
      await _repo(a).initiate(businessId: 5);
      expect((a.seen.single.body as Map).containsKey('operator'), isFalse);
    });

    test('refus du serveur : ApiException avec le code, sans numéro', () async {
      final codes = {
        401: 'NOT_AUTHENTICATED',
        403: 'ACCOUNT_BLOCKED',
        404: 'BUSINESS_NOT_ACTIVE',
        409: 'CHANNEL_UNAVAILABLE',
        429: 'RATE_LIMITED',
      };
      for (final e in codes.entries) {
        final a = FakeAdapter((r) =>
            FakeAdapter.reply(e.key, {'code': e.value, 'message': 'refus'}));
        // 401 : le client tente un renouvellement s'il en a un ; ici il n'en a pas.
        await expectLater(
          _repo(a).initiate(businessId: 5),
          throwsA(isA<ApiException>()
              .having((x) => x.serverCode, 'serverCode', e.value)
              .having((x) => x.statusCode, 'statusCode', e.key)),
        );
      }
    });

    test('réponse sans numéro ou mal formée : erreur inconnue, sans détail', () async {
      for (final body in <Object?>[
        {'call_id': 3},
        {'call_id': 3, 'phone': ''},
        {'phone': kFakePhone},
        ['liste'],
      ]) {
        final a = FakeAdapter((r) => FakeAdapter.reply(200, body));
        await expectLater(
          _repo(a).initiate(businessId: 5),
          throwsA(isA<ApiException>()
              .having((x) => x.code, 'code', ApiErrorCode.unknown)
              .having((x) => x.toString(), 'toString', isNot(contains(kFakeDigits)))),
        );
      }
    });

    test('dépôt factice : numéro fictif D-18, jamais dans toString', () async {
      final s = await CallRepositoryFake().initiate(businessId: 1, line: CallLine.orange);
      expect(s.phone, startsWith('+237600000'));
      expect(s.toString(), isNot(contains('600000')));
    });
  });

  group('PlatformCallChannel (canal cm.netbuis/call)', () {
    const channel = PlatformCallChannel.channel;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> seen;

    void mock(Future<Object?> Function(MethodCall) h) {
      seen = [];
      messenger.setMockMethodCallHandler(channel, (c) {
        seen.add(c);
        return h(c);
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }

    test('permissions et lignes lues', () async {
      mock((c) async => switch (c.method) {
            'permissions' => {'granted': true, 'asked': false},
            'listSims' => [
                {'id': 'a|1', 'label': 'SIM 1', 'carrier': 'Orange'},
                {'id': 'b|2', 'label': 'SIM 2'},
                {'label': 'sans id'},
              ],
            _ => null,
          });
      const ch = PlatformCallChannel();
      final p = await ch.permissions();
      expect(p.granted, isTrue);
      expect(p.asked, isFalse);
      final sims = await ch.listSims();
      expect(sims.map((s) => s.id), ['a|1', 'b|2']);
      expect(sims.first.carrier, 'Orange');
    });

    test('placeCall transmet numéro et compte ; réponses traduites', () async {
      var reply = 'placed';
      mock((c) async => reply);
      const ch = PlatformCallChannel();
      expect(await ch.placeCall(phone: kFakePhone, accountId: 'a|1'), PlaceCallResult.placed);
      expect(seen.single.method, 'placeCall');
      expect(seen.single.arguments, {'phone': kFakePhone, 'accountId': 'a|1'});
      for (final e in {
        'no_permission': PlaceCallResult.permissionDenied,
        'no_account': PlaceCallResult.accountMissing,
        'failed': PlaceCallResult.failed,
        'autre': PlaceCallResult.failed,
      }.entries) {
        reply = e.key;
        expect(await ch.placeCall(phone: kFakePhone), e.value);
      }
    });

    test('dial et requestPermissions', () async {
      mock((c) async => true);
      const ch = PlatformCallChannel();
      expect(await ch.dial(kFakePhone), isTrue);
      expect(await ch.requestPermissions(), isTrue);
      mock((c) async => false);
      expect(await ch.dial(kFakePhone), isFalse);
    });

    test('erreur du code natif ou canal absent : CallChannelException sans le numéro', () async {
      mock((c) async => throw PlatformException(code: 'x', message: 'numéro $kFakePhone'));
      const ch = PlatformCallChannel();
      await expectLater(
        ch.placeCall(phone: kFakePhone),
        throwsA(isA<CallChannelException>()
            .having((e) => e.toString(), 'toString', isNot(contains(kFakeDigits)))),
      );
      messenger.setMockMethodCallHandler(channel, null);
      await expectLater(ch.listSims(), throwsA(isA<CallChannelException>()));
    });
  });

  group('aucune trace du numéro dans le code', () {
    // Le numéro ne doit être ni journalisé ni affiché : on interdit les API de journal
    // dans tout le dossier de l'appel (Dart) et dans le module Kotlin.
    final forbiddenDart = RegExp(r'\b(print|debugPrint|log|developer\.log|stdout\.write|stderr\.write)\s*\(');
    final forbiddenKotlin = RegExp(r'\b(Log\.[a-z]\(|println\(|print\(|Timber\.|Logger)');

    test('Dart : aucun print / debugPrint / log dans features/call', () {
      final files = Directory('lib/features/call')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(files, isNotEmpty);
      for (final f in files) {
        final code = f.readAsLinesSync().where((l) => !l.trimLeft().startsWith('//')).join('\n');
        expect(forbiddenDart.hasMatch(code), isFalse, reason: f.path);
      }
    });

    test('Kotlin : aucun journal, et aucun stockage du numéro dans CallChannel.kt', () {
      final code = File('android/app/src/main/kotlin/cm/netbuis/netbuis/CallChannel.kt')
          .readAsLinesSync()
          .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
      }).join('\n');
      expect(forbiddenKotlin.hasMatch(code), isFalse);
      // Le numéro ne va jamais dans les préférences ni dans un message d'erreur.
      expect(code.contains('putString'), isFalse);
      expect(code.contains('result.error'), isFalse);
    });

    test('le manifeste déclare CALL_PHONE et READ_PHONE_STATE, pas READ_CALL_LOG', () {
      final m = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(m, contains('android.permission.CALL_PHONE'));
      expect(m, contains('android.permission.READ_PHONE_STATE'));
      expect(m, isNot(contains('READ_CALL_LOG')));
    });
  });
}
