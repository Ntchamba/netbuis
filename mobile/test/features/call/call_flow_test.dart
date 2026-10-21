import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/features/call/application/call_controller.dart';
import 'package:netbuis/features/call/data/call_channel.dart';
import 'package:netbuis/features/call/data/models/call_session.dart';

import 'call_test_helpers.dart';

void main() {
  late FakeCallChannel channel;
  late FakeCallRepository repo;

  setUp(() {
    channel = FakeCallChannel();
    repo = FakeCallRepository();
  });

  Future<void> open(WidgetTester tester, {TargetPlatform? platform}) async {
    await pumpCallHost(tester,
        channel: channel, repo: repo, platform: platform ?? TargetPlatform.android);
    await tapAndSettle(tester, find.byKey(kOpenCall));
  }

  group('feuille Orange / MTN', () {
    testWidgets('deux gros boutons (icône + mot), Annuler, nom du commerce, jamais le numéro',
        (tester) async {
      await open(tester);
      expect(find.byKey(const Key('call-choose')), findsOneWidget);
      expect(find.text('Vous appelez'), findsOneWidget);
      expect(find.text('Chez Aminatou'), findsOneWidget);
      expect(find.text('Avec quelle ligne voulez-vous appeler ?'), findsOneWidget);
      for (final k in ['call-orange', 'call-mtn']) {
        final b = find.byKey(Key(k));
        expect(b, findsOneWidget);
        expect(find.descendant(of: b, matching: find.byIcon(Icons.call)), findsOneWidget);
        expect(tester.getSize(b).height, greaterThanOrEqualTo(64));
      }
      expect(find.descendant(of: find.byKey(const Key('call-orange')), matching: find.text('Orange')),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('call-mtn')), matching: find.text('MTN')),
          findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
      // Texte honnête D-07, affiché même si iOS est reporté.
      expect(find.byKey(const Key('call-honest')), findsOneWidget);
      expect(find.textContaining("n'affiche jamais le numéro"), findsOneWidget);
      // Rien n'est demandé au serveur avant le choix de la ligne.
      expect(repo.requests, isEmpty);
      expect(channel.placed, isEmpty);
      expectNoPhoneOnScreen(tester);
    });

    testWidgets('choisir Orange EST la confirmation : POST immédiat, appel natif sur la bonne SIM, '
        '« Appel en cours... », puis fermeture', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('call-orange')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.requests, [(businessId: 5, line: CallLine.orange)]);
      // Le numéro reçu est passé tel quel au code natif, avec le compte Orange.
      expect(channel.placed, [(phone: kFakePhone, accountId: 'tel|orange')]);
      expect(find.byKey(const Key('call-running')), findsOneWidget);
      expect(find.text('Appel en cours...'), findsOneWidget);
      expect(find.text('Chez Aminatou · ligne Orange'), findsOneWidget);
      expect(find.byKey(const Key('call-orange')), findsNothing);
      expectNoPhoneOnScreen(tester);
      await closeSheet(tester);
      expect(find.byKey(const Key('call-sheet')), findsNothing);
    });

    testWidgets('choisir MTN : appel sur le compte MTN', (tester) async {
      await open(tester);
      await tapAndSettle(tester, find.byKey(const Key('call-mtn')));
      expect(repo.requests.single.line, CallLine.mtn);
      expect(channel.placed.single.accountId, 'tel|mtn');
      expect(find.text('Chez Aminatou · ligne MTN'), findsOneWidget);
      expectNoPhoneOnScreen(tester);
      await closeSheet(tester);
    });

    testWidgets('Annuler : rien n\'est demandé au serveur ni lancé', (tester) async {
      await open(tester);
      await tapAndSettle(tester, find.byKey(const Key('call-cancel')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('call-sheet')), findsNothing);
      expect(repo.requests, isEmpty);
      expect(channel.placed, isEmpty);
    });

    testWidgets('la ligne est redemandée à chaque appel (D-22, pas de mémoire)', (tester) async {
      await open(tester);
      await tapAndSettle(tester, find.byKey(const Key('call-orange')));
      await closeSheet(tester);
      expect(find.byKey(const Key('call-sheet')), findsNothing);
      await tapAndSettle(tester, find.byKey(kOpenCall));
      expect(find.byKey(const Key('call-choose')), findsOneWidget);
      await tapAndSettle(tester, find.byKey(const Key('call-mtn')));
      expect(channel.placed.map((p) => p.accountId), ['tel|orange', 'tel|mtn']);
      expect(repo.requests.map((r) => r.line), [CallLine.orange, CallLine.mtn]);
      await closeSheet(tester);
    });
  });

  group('double clic', () {
    testWidgets('deux touchers sur Appeler : une seule feuille', (tester) async {
      await pumpCallHost(tester, channel: channel, repo: repo);
      await tester.tap(find.byKey(kOpenCall));
      await tester.tap(find.byKey(kOpenCall), warnIfMissed: false);
      await settleSheet(tester);
      expect(find.byKey(const Key('call-sheet')), findsOneWidget);
      expect(find.byKey(const Key('call-choose')), findsOneWidget);
    });

    testWidgets('deux touchers sur Orange : un seul POST et un seul appel natif', (tester) async {
      await open(tester);
      final orange = find.byKey(const Key('call-orange'));
      await tester.tap(orange);
      await tester.tap(orange, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.requests, hasLength(1));
      expect(channel.placed, hasLength(1));
      await closeSheet(tester);
    });

    testWidgets('begin() est refusé tant qu\'un appel est en cours', (tester) async {
      await open(tester);
      final container = ProviderScope.containerOf(tester.element(find.byKey(const Key('call-sheet'))));
      final flow = container.read(callFlowProvider.notifier);
      expect(flow.begin(9, 'Autre'), isFalse);
      expect(container.read(callFlowProvider).businessId, 5);
      await tapAndSettle(tester, find.byKey(const Key('call-cancel')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(container.read(callFlowProvider).phase, CallPhase.idle);
    });
  });

  group('téléphone à une SIM, ligne absente, SIM non reconnue', () {
    testWidgets('une seule SIM : la feuille est sautée, l\'appel part tout de suite', (tester) async {
      channel.sims = const [orangeSim];
      await open(tester);
      expect(find.byKey(const Key('call-choose')), findsNothing);
      expect(find.byKey(const Key('call-orange')), findsNothing);
      expect(repo.requests, [(businessId: 5, line: CallLine.orange)]);
      expect(channel.placed, [(phone: kFakePhone, accountId: 'tel|orange')]);
      expect(find.text('Appel en cours...'), findsOneWidget);
      expectNoPhoneOnScreen(tester);
      await closeSheet(tester);
      expect(find.byKey(const Key('call-sheet')), findsNothing);
    });

    testWidgets('une seule SIM d\'un autre opérateur : appel sans ligne annoncée', (tester) async {
      channel.sims = const [SimAccount(id: 'tel|x', label: 'Perso', carrier: '')];
      await open(tester);
      expect(repo.requests.single.line, isNull);
      expect(channel.placed.single.accountId, 'tel|x');
      expect(find.text('Chez Aminatou · ligne Perso'), findsNothing);
      await closeSheet(tester);
    });

    testWidgets('ligne choisie absente : message simple qui propose l\'autre ligne', (tester) async {
      channel.sims = const [orangeSim, otherSim];
      await open(tester);
      await tapAndSettle(tester, find.byKey(const Key('call-mtn')));
      expect(find.byKey(const Key('call-absent')), findsOneWidget);
      expect(find.text("Votre téléphone n'a pas de ligne MTN."), findsOneWidget);
      expect(find.text('Appeler avec Orange'), findsOneWidget);
      // Toujours rien envoyé : ce n'est pas encore une confirmation.
      expect(repo.requests, isEmpty);
      expect(channel.placed, isEmpty);
      await tapAndSettle(tester, find.byKey(const Key('call-other-line')));
      expect(repo.requests.single.line, CallLine.orange);
      expect(channel.placed.single.accountId, 'tel|orange');
      expectNoPhoneOnScreen(tester);
      await closeSheet(tester);
    });

    testWidgets('ligne absente puis Annuler : aucun appel', (tester) async {
      channel.sims = const [mtnSim, otherSim];
      await open(tester);
      await tapAndSettle(tester, find.byKey(const Key('call-orange')));
      expect(find.text("Votre téléphone n'a pas de ligne Orange."), findsOneWidget);
      expect(find.text('Appeler avec MTN'), findsOneWidget);
      await tapAndSettle(tester, find.byKey(const Key('call-cancel')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('call-sheet')), findsNothing);
      expect(repo.requests, isEmpty);
    });

    testWidgets('SIM renommée / eSIM : repli avec les noms donnés par le système', (tester) async {
      channel.sims = const [
        SimAccount(id: 'tel|a', label: 'Perso'),
        SimAccount(id: 'tel|b', label: 'Travail', carrier: 'CM'),
      ];
      await open(tester);
      expect(find.byKey(const Key('call-orange')), findsNothing);
      expect(find.byKey(const Key('call-pick-sim')), findsOneWidget);
      expect(find.text('Perso'), findsOneWidget);
      expect(find.text('Travail (CM)'), findsOneWidget);
      expect(repo.requests, isEmpty);
      await tapAndSettle(tester, find.byKey(const Key('call-sim-1')));
      // Opérateur inconnu : pas d'opérateur annoncé au serveur, mais le bon compte appelé.
      expect(repo.requests.single.line, isNull);
      expect(channel.placed, [(phone: kFakePhone, accountId: 'tel|b')]);
      expect(find.text('Chez Aminatou · ligne Travail (CM)'), findsOneWidget);
      expectNoPhoneOnScreen(tester);
      await closeSheet(tester);
    });

    testWidgets('deux SIM du même opérateur : repli sur les noms, et Orange reconnu est annoncé',
        (tester) async {
      channel.sims = const [
        SimAccount(id: 'tel|1', label: 'Orange 1', carrier: 'Orange CM'),
        SimAccount(id: 'tel|2', label: 'Orange 2', carrier: 'Orange CM'),
      ];
      await open(tester);
      expect(find.byKey(const Key('call-pick-sim')), findsOneWidget);
      await tapAndSettle(tester, find.byKey(const Key('call-sim-0')));
      expect(repo.requests.single.line, CallLine.orange);
      expect(channel.placed.single.accountId, 'tel|1');
      await closeSheet(tester);
    });
  });

  group('autorisations et repli composeur', () {
    testWidgets('autorisation manquante : explication d\'abord, puis demande Android, puis feuille',
        (tester) async {
      channel.perms = const CallPermissions(granted: false, asked: false);
      await open(tester);
      expect(find.byKey(const Key('call-rationale')), findsOneWidget);
      expect(find.text("Autoriser l'appel direct ?"), findsOneWidget);
      expect(channel.requestCount, 0, reason: 'l\'explication précède la demande Android');
      await tapAndSettle(tester, find.byKey(const Key('call-rationale-ok')));
      expect(channel.requestCount, 1);
      expect(find.byKey(const Key('call-choose')), findsOneWidget);
    });

    testWidgets('« Plus tard » : on ferme, aucune demande Android, aucun appel', (tester) async {
      channel.perms = const CallPermissions(granted: false, asked: false);
      await open(tester);
      await tapAndSettle(tester, find.byKey(const Key('call-rationale-cancel')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('call-sheet')), findsNothing);
      expect(channel.requestCount, 0);
      expect(repo.requests, isEmpty);
    });

    testWidgets('autorisation refusée : avertissement clair, puis composeur (ACTION_DIAL)',
        (tester) async {
      channel.perms = const CallPermissions(granted: false, asked: false);
      channel.grantOnRequest = false;
      await open(tester);
      await tapAndSettle(tester, find.byKey(const Key('call-rationale-ok')));
      expect(find.byKey(const Key('call-dial-warning')), findsOneWidget);
      expect(find.text('Appel par le composeur du téléphone'), findsOneWidget);
      expect(find.textContaining('sera visible à l\'écran'), findsOneWidget);
      // Avertissement affiché AVANT toute demande au serveur.
      expect(repo.requests, isEmpty);
      expect(channel.dialed, isEmpty);
      await tapAndSettle(tester, find.byKey(const Key('call-dial-ok')));
      expect(repo.requests.single.line, isNull);
      expect(channel.dialed, [kFakePhone]);
      expect(channel.placed, isEmpty);
      // Le numéro s'affiche dans le composeur du système, jamais dans NetBuis.
      expectNoPhoneOnScreen(tester);
      await closeSheet(tester);
    });

    testWidgets('autorisation déjà demandée une fois et refusée : pas de nouvelle demande, repli direct',
        (tester) async {
      channel.perms = const CallPermissions(granted: false, asked: true);
      await open(tester);
      expect(find.byKey(const Key('call-rationale')), findsNothing);
      expect(find.byKey(const Key('call-dial-warning')), findsOneWidget);
      expect(channel.requestCount, 0);
    });

    testWidgets('annuler l\'avertissement : aucun POST, aucun composeur', (tester) async {
      channel.perms = const CallPermissions(granted: false, asked: true);
      await open(tester);
      await tapAndSettle(tester, find.byKey(const Key('call-cancel')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(repo.requests, isEmpty);
      expect(channel.dialed, isEmpty);
    });

    testWidgets('lecture des autorisations impossible : repli composeur avec avertissement',
        (tester) async {
      channel.throwOnPermissions = true;
      await open(tester);
      expect(find.byKey(const Key('call-dial-warning')), findsOneWidget);
    });

    testWidgets('aucune ligne lisible (détection impossible) : repli composeur', (tester) async {
      channel.sims = const [];
      await open(tester);
      expect(find.byKey(const Key('call-dial-warning')), findsOneWidget);
      await tapAndSettle(tester, find.byKey(const Key('call-dial-ok')));
      expect(channel.dialed, [kFakePhone]);
      await closeSheet(tester);
    });

    testWidgets('composeur introuvable : message simple', (tester) async {
      channel.sims = const [];
      channel.dialResult = false;
      await open(tester);
      await tapAndSettle(tester, find.byKey(const Key('call-dial-ok')));
      expect(find.text("Le téléphone n'a pas pu lancer l'appel. Réessayez."), findsOneWidget);
      expectNoPhoneOnScreen(tester);
    });
  });

  group('échecs', () {
    for (final r in [
      PlaceCallResult.permissionDenied,
      PlaceCallResult.accountMissing,
      PlaceCallResult.failed,
    ]) {
      testWidgets('le téléphone répond $r : message simple, rien n\'est affiché', (tester) async {
        channel.placeResult = r;
        await open(tester);
        await tapAndSettle(tester, find.byKey(const Key('call-orange')));
        expect(find.text("Le téléphone n'a pas pu lancer l'appel. Réessayez."), findsOneWidget);
        expectNoPhoneOnScreen(tester);
        await tapAndSettle(tester, find.byKey(const Key('call-close')));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byKey(const Key('call-sheet')), findsNothing);
      });
    }

    testWidgets('le code natif plante : message simple', (tester) async {
      channel.throwOnPlace = true;
      await open(tester);
      await tapAndSettle(tester, find.byKey(const Key('call-mtn')));
      expect(find.text("Le téléphone n'a pas pu lancer l'appel. Réessayez."), findsOneWidget);
    });

    const refusals = <(String, ApiException, String)>[
      ('RATE_LIMITED', ApiException(ApiErrorCode.tooManyRequests, statusCode: 429, serverCode: 'RATE_LIMITED'),
          'Vous avez fait beaucoup d\'appels. Réessayez un peu plus tard.'),
      ('ACCOUNT_BLOCKED', ApiException(ApiErrorCode.unknown, statusCode: 403, serverCode: 'ACCOUNT_BLOCKED'),
          'Votre compte est bloqué. Contactez le support NetBuis.'),
      ('BUSINESS_NOT_ACTIVE', ApiException(ApiErrorCode.unknown, statusCode: 404, serverCode: 'BUSINESS_NOT_ACTIVE'),
          "Ce commerce n'est plus disponible."),
      ('OWN_BUSINESS', ApiException(ApiErrorCode.unknown, statusCode: 403, serverCode: 'OWN_BUSINESS'),
          "C'est votre propre commerce : vous ne pouvez pas l'appeler."),
      ('NOT_AUTHENTICATED', ApiException(ApiErrorCode.unknown, statusCode: 401, serverCode: 'NOT_AUTHENTICATED'),
          'Connectez-vous pour appeler ce commerce.'),
      ('CHANNEL_UNAVAILABLE', ApiException(ApiErrorCode.unknown, statusCode: 409, serverCode: 'CHANNEL_UNAVAILABLE'),
          'Ce commerce ne peut pas être appelé pour le moment.'),
      ('réseau coupé', ApiException(ApiErrorCode.network),
          'Pas de connexion. Vérifiez votre réseau et réessayez.'),
      ('erreur 500', ApiException(ApiErrorCode.unknown, statusCode: 500),
          "L'appel n'a pas pu être lancé. Réessayez."),
    ];
    for (final (name, error, message) in refusals) {
      testWidgets('refus du serveur $name : message simple, aucun appel natif', (tester) async {
        repo.error = error;
        await open(tester);
        await tapAndSettle(tester, find.byKey(const Key('call-orange')));
        expect(repo.requests, hasLength(1));
        expect(find.byKey(const Key('call-error')), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        expect(channel.placed, isEmpty);
        expect(channel.dialed, isEmpty);
        expectNoPhoneOnScreen(tester);
        await tapAndSettle(tester, find.byKey(const Key('call-close')));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byKey(const Key('call-sheet')), findsNothing);
      });
    }

    test('erreur inattendue (non ApiException) : message générique ; 401/429/404 sans code lisible', () {
      expect(callErrorFor(StateError('x')), CallError.generic);
      expect(callErrorFor(const ApiException(ApiErrorCode.unknown, statusCode: 429)),
          CallError.rateLimited);
      expect(callErrorFor(const ApiException(ApiErrorCode.unknown, statusCode: 401)),
          CallError.notAuthenticated);
      expect(callErrorFor(const ApiException(ApiErrorCode.unknown, statusCode: 404)),
          CallError.businessNotActive);
    });
  });

  group('plateforme', () {
    testWidgets('iPhone : appel direct indisponible, texte honnête D-07, aucun appel', (tester) async {
      await open(tester, platform: TargetPlatform.iOS);
      expect(find.byKey(const Key('call-unsupported')), findsOneWidget);
      expect(find.textContaining('pas encore disponible sur iPhone'), findsOneWidget);
      expect(find.textContaining("n'affiche jamais le numéro"), findsOneWidget);
      expect(repo.requests, isEmpty);
      expect(channel.placed, isEmpty);
      expect(channel.dialed, isEmpty);
    });
  });

  group('le numéro ne fuit pas', () {
    test('toString des modèles et de l\'état ne contient jamais le numéro', () {
      const session = CallSession(callId: 7, phone: kFakePhone);
      expect(session.toString(), isNot(contains(kFakeDigits)));
      expect(session.toString(), 'CallSession(callId: 7)');
      expect('${const CallFlowState(businessName: 'X')}', isNot(contains('237')));
      expect(const CallChannelException().toString(), 'CallChannelException');
      expect(orangeSim.toString(), isNot(contains('tel|')));
    });

    testWidgets('à chaque étape du parcours, le numéro n\'est dans aucun widget', (tester) async {
      channel.sims = const [orangeSim, mtnSim];
      await pumpCallHost(tester, channel: channel, repo: repo);
      expectNoPhoneOnScreen(tester);
      await tapAndSettle(tester, find.byKey(kOpenCall));
      expectNoPhoneOnScreen(tester);
      await tester.tap(find.byKey(const Key('call-mtn')));
      await tester.pump();
      expectNoPhoneOnScreen(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expectNoPhoneOnScreen(tester);
      await closeSheet(tester);
      expectNoPhoneOnScreen(tester);
      expect(find.textContaining('+237'), findsNothing);
    });

    testWidgets('le contrôle de fuite détecte bien un numéro affiché (cas qui doit échouer)',
        (tester) async {
      await tester.pumpWidget(testApp(const Scaffold(body: Text(kFakePhone))));
      await tester.pumpAndSettle();
      expect(() => expectNoPhoneOnScreen(tester), throwsA(isA<TestFailure>()));
    });
  });
}
