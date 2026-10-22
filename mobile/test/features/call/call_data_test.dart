import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/network/dio_client.dart';
import 'package:netbuis/features/call/data/call_channel.dart';
import 'package:netbuis/features/call/data/models/call_history_entry.dart';
import 'package:netbuis/features/call/data/models/call_session.dart';
import 'package:netbuis/features/call/data/repositories/call_repository_api.dart';
import 'package:netbuis/features/call/data/repositories/call_repository_fake.dart';

import '../auth/auth_test_helpers.dart';
import '../business/business_submit_helpers.dart' show kApiUrl;
import 'call_test_helpers.dart' show kFakeDigits, kSessionId;

CallRepositoryApi _repo(HttpClientAdapter a) => CallRepositoryApi(
    buildDio(baseUrl: kApiUrl, readAccessToken: () async => 'acc-test')..httpClientAdapter = a);

const _start = {
  'session_id': kSessionId,
  'state': 'ringing',
  'code': null,
  'ring_seconds': 30,
  'jitsi': {'domain': 'jitsi.exemple.test', 'room': 'salle-secrete', 'jwt': 'jeton-secret'},
};

/// Adaptateur qui répond par un flux d'octets (SSE).
class _SseAdapter implements HttpClientAdapter {
  _SseAdapter(this.text);
  final String text;
  RequestOptions? seen;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
      Future<void>? cancelFuture) async {
    seen = options;
    return ResponseBody(Stream.value(Uint8List.fromList(utf8.encode(text))), 200,
        headers: {Headers.contentTypeHeader: ['text/event-stream']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('POST /calls/sessions/', () {
    test('corps {business_id} et réponse lue, sans fuite dans toString', () async {
      final a = FakeAdapter((r) => FakeAdapter.reply(200, _start));
      final s = await _repo(a).startSession(businessId: 5);
      expect(a.seen.single.method, 'POST');
      expect(a.seen.single.path, '/calls/sessions/');
      expect(a.seen.single.body, {'business_id': 5});
      expect(s.state, CallState.ringing);
      expect(s.ringSeconds, 30);
      expect(s.jitsi!.serverUrl, 'https://jitsi.exemple.test');
      expect(s.jitsi!.room, 'salle-secrete');
      expect('${s.jitsi}$s', isNot(contains('salle-secrete')));
      expect('${s.jitsi}', isNot(contains('jeton-secret')));
    });

    test('sans commerce : corps vide', () async {
      final a = FakeAdapter((r) => FakeAdapter.reply(200, _start));
      await _repo(a).startSession();
      expect(a.seen.single.body, <String, Object?>{});
    });

    test('personne de disponible : état unavailable, jitsi null', () async {
      final a = FakeAdapter((r) => FakeAdapter.reply(200, {
            'session_id': kSessionId,
            'state': 'unavailable',
            'code': 'no_agent_available',
            'jitsi': null,
            'ring_seconds': 0,
          }));
      final s = await _repo(a).startSession(businessId: 5);
      expect(s.state, CallState.unavailable);
      expect(s.jitsi, isNull);
      expect(s.code, 'no_agent_available');
    });

    test('refus du serveur : ApiException avec le code', () async {
      final codes = {
        403: 'account_blocked',
        404: 'BUSINESS_NOT_ACTIVE',
        429: 'RATE_LIMITED',
        503: 'jitsi_not_configured',
      };
      for (final e in codes.entries) {
        final a = FakeAdapter((r) => FakeAdapter.reply(e.key, {'code': e.value, 'message': 'refus'}));
        await expectLater(
          _repo(a).startSession(businessId: 5),
          throwsA(isA<ApiException>()
              .having((x) => x.serverCode, 'serverCode', e.value)
              .having((x) => x.statusCode, 'statusCode', e.key)),
        );
      }
    });

    test('409 call_already_active : numéro de la session en cours conservé', () async {
      final a = FakeAdapter((r) => FakeAdapter.reply(
          409, {'code': 'call_already_active', 'message': 'x', 'session_id': 'abc'}));
      await expectLater(_repo(a).startSession(businessId: 5),
          throwsA(isA<ActiveCallException>().having((x) => x.sessionId, 'sessionId', 'abc')));
    });

    test('réponse mal formée : erreur inconnue, sans détail ni salle', () async {
      for (final body in <Object?>[
        {'session_id': kSessionId, 'state': 'ringing', 'ring_seconds': 30, 'jitsi': null},
        {'session_id': kSessionId, 'state': 'bizarre', 'ring_seconds': 30},
        {'state': 'ringing', 'ring_seconds': 30, 'jitsi': _start['jitsi']},
        {
          'session_id': kSessionId,
          'state': 'ringing',
          'ring_seconds': 30,
          'jitsi': {'domain': 'd', 'room': '', 'jwt': 'j'}
        },
        ['liste'],
      ]) {
        final a = FakeAdapter((r) => FakeAdapter.reply(200, body));
        await expectLater(
          _repo(a).startSession(businessId: 5),
          throwsA(isA<ApiException>()
              .having((x) => x.code, 'code', ApiErrorCode.unknown)
              .having((x) => x.toString(), 'toString', isNot(contains('salle')))),
        );
      }
    });
  });

  group('suivi de la session', () {
    test('status, cancel, end : bons chemins', () async {
      final a = FakeAdapter((r) =>
          FakeAdapter.reply(200, {'session_id': kSessionId, 'state': 'ended', 'end_reason': 'caller_hangup'}));
      final repo = _repo(a);
      expect((await repo.status(kSessionId)).state, CallState.ended);
      await repo.cancel(kSessionId);
      await repo.end(kSessionId);
      expect(a.seen.map((r) => '${r.method} ${r.path}'), [
        'GET /calls/sessions/$kSessionId/',
        'POST /calls/sessions/$kSessionId/cancel/',
        'POST /calls/sessions/$kSessionId/end/',
      ]);
    });

    test('flux SSE : états lus, commentaires et événements inconnus ignorés', () async {
      const text = 'retry: 2000\n\n'
          'event: state\ndata: {"session_id":"$kSessionId","state":"ringing","reason":""}\n\n'
          ': keepalive\n\n'
          'event: autre\ndata: {"x":1}\n\n'
          'event: state\ndata: {oups\n\n'
          'event: state\ndata: {"session_id":"$kSessionId","state":"answered","reason":""}\n\n'
          'event: state\ndata: {"session_id":"$kSessionId","state":"ended","reason":"agent_hangup"}\n\n';
      final a = _SseAdapter(text);
      final got = await _repo(a).watch(kSessionId).toList();
      expect(got.map((s) => s.state), [CallState.ringing, CallState.answered, CallState.ended]);
      expect(got.last.reason, 'agent_hangup');
      expect(a.seen!.path, '/calls/sessions/$kSessionId/events/');
      expect(a.seen!.headers['Accept'], 'text/event-stream');
      expect(a.seen!.receiveTimeout, Duration.zero);
    });

    test('flux SSE : refus du serveur = erreur typée', () async {
      final a = FakeAdapter((r) => FakeAdapter.reply(404, {'code': 'not_found', 'message': 'x'}));
      await expectLater(_repo(a).watch(kSessionId).toList(), throwsA(isA<ApiException>()));
    });

    test('warmUp : OPTIONS sur la route d\'appel, ne lève jamais', () async {
      final a = FakeAdapter((r) => FakeAdapter.reply(200, {}));
      await _repo(a).warmUp();
      expect(a.seen.single.method, 'OPTIONS');
      expect(a.seen.single.path, '/calls/sessions/');
      final bad = FakeAdapter((r) => FakeAdapter.reply(500, {}));
      await _repo(bad).warmUp();
    });

    test('dépôt factice : une équipe fictive, aucun numéro', () async {
      final repo = CallRepositoryFake(answerAfter: const Duration(milliseconds: 10));
      final s = await repo.startSession(businessId: 1);
      expect(s.state, CallState.ringing);
      final first = await repo.watch(s.sessionId).first;
      expect(first.state, CallState.answered);
      expect('$s${s.jitsi}', isNot(contains('+237')));
    });
  });

  group('POST /calls/whatsapp/', () {
    test('corps {business_id, platform} et lien lu', () async {
      final a = FakeAdapter((r) =>
          FakeAdapter.reply(200, {'call_id': 9, 'wa_url': 'https://wa.me/237600000042?text=Bonjour'}));
      final link = await _repo(a).initiateWhatsapp(businessId: 5);
      expect(a.seen.single.path, '/calls/whatsapp/');
      expect(a.seen.single.body, {'business_id': 5, 'platform': 'android'});
      expect(link.callId, 9);
      expect(link.toString(), isNot(contains(kFakeDigits)));
    });

    test('lien hors wa.me : refusé sans détail', () async {
      final a = FakeAdapter((r) =>
          FakeAdapter.reply(200, {'call_id': 9, 'wa_url': 'https://exemple.test/237600000042'}));
      await expectLater(
          _repo(a).initiateWhatsapp(businessId: 5),
          throwsA(isA<ApiException>()
              .having((x) => x.toString(), 'toString', isNot(contains(kFakeDigits)))));
    });
  });

  group('historique fusionné', () {
    test('session_id OU id', () {
      final call = CallHistoryEntry.fromJson({
        'id': null,
        'session_id': kSessionId,
        'type': 'call',
        'state': 'missed',
        'business_id': null,
        'business_name': null,
        'zone': null,
        'date': '2026-10-22T10:00:00Z',
        'feedback': null,
      });
      expect(call.state, CallState.missed);
      expect(call.businessId, isNull);
      expect(call.key, 's$kSessionId');
      final wa = CallHistoryEntry.fromJson({
        'id': 4,
        'session_id': null,
        'type': 'whatsapp',
        'state': null,
        'business_id': 2,
        'business_name': 'Chez X',
        'zone': 'Hardé',
        'date': '2026-10-22T10:00:00Z',
        'feedback': null,
      });
      expect(wa.type, HistoryType.whatsapp);
      expect(wa.key, 'w4');
    });

    test('ni id ni session_id : refusé', () {
      expect(
          () => CallHistoryEntry.fromJson({'type': 'call', 'date': '2026-10-22T10:00:00Z'}),
          throwsFormatException);
    });
  });

  group('PlatformCallChannel (canal cm.netbuis/call)', () {
    const channel = PlatformCallChannel.channel;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    void mock(Future<Object?> Function(MethodCall) h) {
      messenger.setMockMethodCallHandler(channel, h);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }

    test('micro lu et demandé', () async {
      mock((c) async => switch (c.method) {
            'microphone' => {'granted': false, 'asked': true},
            'requestMicrophone' => true,
            _ => null,
          });
      const ch = PlatformCallChannel();
      final m = await ch.microphone();
      expect(m.granted, isFalse);
      expect(m.asked, isTrue);
      expect(await ch.requestMicrophone(), isTrue);
    });

    test('erreur du code natif ou canal absent : CallChannelException', () async {
      mock((c) async => throw PlatformException(code: 'x', message: 'détail'));
      const ch = PlatformCallChannel();
      await expectLater(ch.microphone(), throwsA(isA<CallChannelException>()));
      messenger.setMockMethodCallHandler(channel, null);
      await expectLater(ch.requestMicrophone(), throwsA(isA<CallChannelException>()));
    });
  });

  group('rien de l\'ancien appel téléphonique, aucune trace de la salle', () {
    final forbiddenDart =
        RegExp(r'\b(print|debugPrint|log|developer\.log|stdout\.write|stderr\.write)\s*\(');
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

    test('CallChannel.kt n\'existe plus ; AppChannel.kt ne journalise ni ne stocke', () {
      expect(File('android/app/src/main/kotlin/cm/netbuis/netbuis/CallChannel.kt').existsSync(),
          isFalse);
      final code = File('android/app/src/main/kotlin/cm/netbuis/netbuis/AppChannel.kt')
          .readAsLinesSync()
          .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
      }).join('\n');
      expect(forbiddenKotlin.hasMatch(code), isFalse);
      expect(code.contains('putString'), isFalse);
      expect(code.contains('result.error'), isFalse);
      for (final gone in ['TelecomManager', 'placeCall', 'CALL_PHONE', 'listSims']) {
        expect(code.contains(gone), isFalse, reason: gone);
      }
    });

    test('le manifeste ne déclare plus de permission téléphone ; micro seulement ; minSdk 24', () {
      final m = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(m, isNot(contains('CALL_PHONE')));
      expect(m, isNot(contains('READ_PHONE_STATE')));
      expect(m, isNot(contains('READ_CALL_LOG')));
      expect(m, contains('android.permission.RECORD_AUDIO'));
      final g = File('android/app/build.gradle.kts').readAsStringSync();
      expect(g, contains('24'));
    });

    test('Jitsi : fichier du service sans journal, vidéo coupée, audio seul', () {
      final code = File('lib/features/call/data/jitsi_service.dart').readAsStringSync();
      expect(code, contains("'startWithVideoMuted': true"));
      expect(code, contains("'startAudioOnly': true"));
      expect(code, contains("'startWithAudioMuted': false"));
    });
  });
}
