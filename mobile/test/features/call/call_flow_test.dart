// Appel à l'équipe NetBuis (T133) : écran d'appel, états, minuteur, annulation, micro, réseau.
// Le service Jitsi est un faux : la salle réelle n'est pas testable sans téléphone.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/features/call/application/call_controller.dart';
import 'package:netbuis/features/call/data/call_channel.dart';
import 'package:netbuis/features/call/data/jitsi_service.dart';
import 'package:netbuis/features/call/data/models/call_session.dart';

import 'call_test_helpers.dart';

void main() {
  late FakeCallChannel channel;
  late FakeCallRepository repo;
  late FakeJitsiService jitsi;

  setUp(() {
    channel = FakeCallChannel();
    repo = FakeCallRepository();
    jitsi = FakeJitsiService();
  });

  Future<void> open(WidgetTester tester, {TargetPlatform platform = TargetPlatform.android}) async {
    await pumpCallHost(tester, channel: channel, repo: repo, jitsi: jitsi, platform: platform);
    await tapAndSettle(tester, find.byKey(kOpenCall));
  }

  Future<void> tick(WidgetTester tester, [int seconds = 1]) async {
    await tester.pump(Duration(seconds: seconds));
  }

  group('parcours normal', () {
    testWidgets('Appeler : session créée, salle rejointe dès l\'envoi, « Appel en cours... », minuteur',
        (tester) async {
      await open(tester);
      expect(repo.requests, [5]);
      expect(jitsi.joinedDomains, ['jitsi.exemple.test']);
      expect(find.byKey(const Key('call-running')), findsOneWidget);
      expect(find.text('Appel en cours...'), findsOneWidget);
      expect(find.text('Au sujet de Chez Aminatou'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      await tick(tester, 3);
      expect(find.text('00:03'), findsOneWidget);
      // Rien de secret ni de numéro à l'écran.
      expectNoPhoneOnScreen(tester);
      expect(find.textContaining('salle-secrete'), findsNothing);
      expect(find.textContaining('jeton-secret'), findsNothing);
    });

    testWidgets('mention « appel avec l\'équipe NetBuis » visible pendant l\'appel', (tester) async {
      await open(tester);
      final notice = find.byKey(const Key('call-notice'));
      expect(notice, findsOneWidget);
      expect(tester.widget<Text>(notice).data, contains('équipe NetBuis'));
    });

    testWidgets('l\'équipe répond : « En communication », minuteur repart de zéro, puis Raccrocher',
        (tester) async {
      await open(tester);
      await tick(tester, 4);
      repo.push(CallState.answered);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('call-connected')), findsOneWidget);
      expect(find.text('En communication'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      await tick(tester, 2);
      expect(find.text('00:02'), findsOneWidget);
      await tester.tap(find.byKey(const Key('call-hangup')));
      await tick(tester);
      expect(repo.ends, [kSessionId]);
      expect(jitsi.hangUps, greaterThan(0));
      expect(find.byKey(const Key('call-ended')), findsOneWidget);
      expect(find.text('Durée : 00:02'), findsOneWidget);
      await tester.tap(find.byKey(const Key('call-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('call-screen')), findsNothing);
    });

    testWidgets('fin d\'appel par l\'équipe : la salle est quittée', (tester) async {
      await open(tester);
      repo.push(CallState.answered);
      await tick(tester);
      repo.push(CallState.ended, reason: 'agent_hangup');
      await tick(tester);
      expect(find.byKey(const Key('call-ended')), findsOneWidget);
      expect(jitsi.hangUps, 1);
      expect(repo.ends, isEmpty, reason: 'c\'est l\'équipe qui a raccroché');
    });

    testWidgets('Jitsi prévient que la salle est jointe : l\'écran Jitsi est réduit une fois',
        (tester) async {
      await open(tester);
      jitsi.emit(JitsiEvent.joined);
      jitsi.emit(JitsiEvent.joined);
      await tick(tester);
      expect(jitsi.minimizes, 1);
    });
  });

  group('annulation', () {
    testWidgets('Annuler pendant la sonnerie : cancel envoyé, salle quittée, écran fermé', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('call-cancel')));
      await tester.pumpAndSettle();
      expect(repo.cancels, [kSessionId]);
      expect(jitsi.hangUps, 1);
      expect(find.byKey(const Key('call-screen')), findsNothing);
    });

    testWidgets('Annuler alors que l\'équipe vient de répondre (409) : l\'appel est raccroché',
        (tester) async {
      repo.cancelError = const ApiException(ApiErrorCode.unknown,
          statusCode: 409, serverCode: 'call_not_ringing');
      await open(tester);
      await tester.tap(find.byKey(const Key('call-cancel')));
      await tester.pumpAndSettle();
      expect(repo.cancels, [kSessionId]);
      expect(repo.ends, [kSessionId]);
    });

    testWidgets('quitter depuis l\'écran Jitsi pendant la sonnerie vaut annulation', (tester) async {
      await open(tester);
      jitsi.emit(JitsiEvent.left);
      await tester.pumpAndSettle();
      expect(repo.cancels, [kSessionId]);
      expect(find.byKey(const Key('call-screen')), findsNothing);
    });

    testWidgets('le retour arrière est bloqué pendant l\'appel', (tester) async {
      await open(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byKey(const Key('call-screen')), findsOneWidget);
    });
  });

  group('états sans conversation', () {
    testWidgets('personne de disponible : message exact, aucune salle rejointe', (tester) async {
      repo.start = const CallStart(
          sessionId: kSessionId,
          state: CallState.unavailable,
          ringSeconds: 0,
          code: 'no_agent_available');
      await open(tester);
      expect(find.text("Personne n'est disponible, réessayez plus tard"), findsOneWidget);
      expect(jitsi.joinedDomains, isEmpty);
      await tester.tap(find.byKey(const Key('call-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('call-screen')), findsNothing);
    });

    testWidgets('sonnerie sans réponse : « Personne n\'a répondu », salle quittée', (tester) async {
      await open(tester);
      repo.push(CallState.missed, reason: 'timeout');
      await tick(tester);
      expect(find.byKey(const Key('call-missed')), findsOneWidget);
      expect(find.text("Personne n'a répondu"), findsOneWidget);
      expect(jitsi.hangUps, 1);
    });

    testWidgets('refusé par l\'équipe', (tester) async {
      await open(tester);
      repo.push(CallState.declined, reason: 'all_declined');
      await tick(tester);
      expect(find.byKey(const Key('call-declined')), findsOneWidget);
      expect(jitsi.hangUps, 1);
    });
  });

  group('micro', () {
    testWidgets('micro jamais demandé : explication, puis Android, puis l\'appel part', (tester) async {
      channel.mic = const MicPermission(granted: false, asked: false);
      await open(tester);
      expect(find.byKey(const Key('call-mic-rationale')), findsOneWidget);
      expect(repo.requests, isEmpty);
      await tapAndSettle(tester, find.byKey(const Key('call-mic-ok')));
      expect(channel.requestCount, 1);
      expect(repo.requests, [5]);
      expect(find.byKey(const Key('call-running')), findsOneWidget);
    });

    testWidgets('micro refusé : message, aucune session, aucune salle', (tester) async {
      channel.mic = const MicPermission(granted: false, asked: true);
      channel.grantOnRequest = false;
      await open(tester);
      expect(find.byKey(const Key('call-mic-denied')), findsOneWidget);
      expect(repo.requests, isEmpty);
      expect(jitsi.joinedDomains, isEmpty);
      await tapAndSettle(tester, find.byKey(const Key('call-mic-retry')));
      expect(channel.requestCount, 1);
      expect(find.byKey(const Key('call-mic-denied')), findsOneWidget);
    });

    testWidgets('micro accordé au second essai : l\'appel part', (tester) async {
      channel.mic = const MicPermission(granted: false, asked: true);
      await open(tester);
      await tapAndSettle(tester, find.byKey(const Key('call-mic-retry')));
      expect(repo.requests, [5]);
    });
  });

  group('erreurs et réseau', () {
    testWidgets('réseau coupé au lancement : message réseau, aucune salle', (tester) async {
      repo.error = const ApiException(ApiErrorCode.network);
      await open(tester);
      expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'), findsOneWidget);
      expect(jitsi.joinedDomains, isEmpty);
    });

    testWidgets('Jitsi non configuré (503) et limite atteinte (429)', (tester) async {
      repo.error = const ApiException(ApiErrorCode.unknown,
          statusCode: 503, serverCode: 'jitsi_not_configured');
      await open(tester);
      expect(find.byKey(const Key('call-error')), findsOneWidget);
      expect(find.textContaining("n'est pas disponible pour le moment"), findsOneWidget);
    });

    testWidgets('appel déjà actif (409) : l\'ancienne session est fermée et un message est donné',
        (tester) async {
      repo.error = const ActiveCallException('vieille-session');
      await open(tester);
      expect(repo.cancels, ['vieille-session']);
      expect(find.textContaining('déjà un appel en cours'), findsOneWidget);
    });

    testWidgets('la salle ne peut pas être rejointe : erreur et session annulée', (tester) async {
      jitsi.joinResult = false;
      await open(tester);
      expect(find.text("La liaison audio n'a pas pu s'établir. Réessayez."), findsOneWidget);
      expect(repo.cancels, [kSessionId]);
    });

    testWidgets('domaine Jitsi invalide : salle injoignable, rien d\'ouvert', (tester) async {
      repo.start = const CallStart(
        sessionId: kSessionId,
        state: CallState.ringing,
        ringSeconds: 30,
        jitsi: JitsiAccess(domain: '10.0.0.1', room: 'salle-secrete-de-test', jwt: 'jeton-secret-de-test'),
      );
      await open(tester);
      expect(find.text("La liaison audio n'a pas pu s'établir. Réessayez."), findsOneWidget);
      expect(jitsi.joinedDomains, isEmpty);
      expect(find.textContaining('jeton-secret-de-test'), findsNothing);
    });

    testWidgets('Jitsi perd la liaison pendant l\'appel', (tester) async {
      await open(tester);
      jitsi.emit(JitsiEvent.failed);
      await tick(tester);
      expect(find.byKey(const Key('call-error')), findsOneWidget);
      expect(jitsi.hangUps, 1);
    });

    testWidgets('flux temps réel coupé : repli par consultation, qui voit la fin', (tester) async {
      repo.watchFails = true;
      await open(tester);
      repo.polledState = CallState.answered;
      await tick(tester, 2);
      expect(find.byKey(const Key('call-connected')), findsOneWidget);
      expect(repo.polls, greaterThan(0));
    });

    testWidgets('flux et consultation en panne : connexion perdue après plusieurs échecs',
        (tester) async {
      repo.watchFails = true;
      repo.statusError = const ApiException(ApiErrorCode.network);
      await open(tester);
      await tick(tester, 2 * kCallPollFailuresBeforeLost + 1);
      expect(find.text('La connexion a été coupée. L\'appel est terminé.'), findsOneWidget);
      expect(jitsi.hangUps, 1);
    });

    testWidgets('iPhone : pas encore disponible', (tester) async {
      await open(tester, platform: TargetPlatform.iOS);
      expect(find.byKey(const Key('call-unsupported')), findsOneWidget);
      expect(repo.requests, isEmpty);
    });

    testWidgets('double clic : un seul appel', (tester) async {
      await pumpCallHost(tester, channel: channel, repo: repo, jitsi: jitsi);
      await tester.tap(find.byKey(kOpenCall));
      await tester.tap(find.byKey(kOpenCall), warnIfMissed: false);
      await settleSheet(tester);
      expect(repo.requests, hasLength(1));
    });
  });

  group('erreurs traduites', () {
    test('callErrorFor', () {
      ApiException e(String code, [int? status]) =>
          ApiException(ApiErrorCode.unknown, serverCode: code, statusCode: status);
      expect(callErrorFor(e('account_blocked', 403)), CallError.accountBlocked);
      expect(callErrorFor(e('RATE_LIMITED', 429)), CallError.rateLimited);
      expect(callErrorFor(e('BUSINESS_NOT_ACTIVE', 404)), CallError.businessNotActive);
      expect(callErrorFor(const ActiveCallException('x')), CallError.alreadyActive);
      expect(callErrorFor(e('', 401)), CallError.notAuthenticated);
      expect(callErrorFor(const ApiException(ApiErrorCode.network)), CallError.network);
      expect(callErrorFor(StateError('x')), CallError.generic);
    });
  });

  group('textes FR + EN', () {
    Map<String, String> read(String l) =>
        (json.decode(File('assets/l10n/$l.json').readAsStringSync()) as Map<String, dynamic>)
            .cast<String, String>();

    test('chaque état et chaque erreur d\'appel a son texte dans les deux langues', () {
      final fr = read('fr');
      final en = read('en');
      final keys = [
        for (final e in CallError.values)
          if (e != CallError.whatsappFailed) 'call.error.${e.name}',
        'call.running', 'call.connected', 'call.hangup', 'call.ended', 'call.unavailable',
        'call.missed', 'call.declined', 'call.notice', 'call.mic.title', 'call.mic.denied.title',
        'call.cancel', 'call.about', 'history.team', 'history.state.missed',
      ];
      for (final k in keys) {
        expect(fr[k], isNotNull, reason: 'fr $k');
        expect(en[k], isNotNull, reason: 'en $k');
        expect(en[k], isNot(fr[k]), reason: 'en $k traduit');
      }
      expect(fr['call.notice'], contains('équipe NetBuis'));
      expect(en['call.notice'], contains('NetBuis team'));
      expect(fr['call.unavailable'], "Personne n'est disponible, réessayez plus tard");
    });

    test('plus aucun texte Orange / MTN / appel direct / SIM pour l\'appel', () {
      for (final l in ['fr', 'en']) {
        final m = read(l);
        for (final k in m.keys.where((k) => k.startsWith('call.'))) {
          expect(m[k]!.toLowerCase(), isNot(contains('orange')), reason: '$l $k');
          expect(m[k]!.toLowerCase(), isNot(contains('mtn')), reason: '$l $k');
          expect(m[k]!.toLowerCase(), isNot(contains('sim')), reason: '$l $k');
        }
      }
    });
  });
}
