import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/features/auth/presentation/screens/login_screen.dart';
import 'package:netbuis/features/auth/presentation/screens/otp_screen.dart';

import 'login_test_helpers.dart';

/// Ouvre l'écran du code après avoir demandé un code pour 6 12 34 56 78.
Future<FlowRepository> openOtp(
  WidgetTester tester, {
  FlowRepository? repository,
  FakeSmsSource? sms,
  double textScale = 1.0,
}) async {
  final repo = repository ?? FlowRepository();
  await pumpAuthApp(tester, repository: repo, sms: sms, textScale: textScale);
  await submitPhone(tester, '612345678');
  expect(find.byType(OtpScreen), findsOneWidget);
  return repo;
}

FilledButton _verifyButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Vérifier'));

bool _loggedIn() => find.byType(NavigationDestination).evaluate().length == 4;

void main() {
  testWidgets('étape code : textes de la maquette, 6 cases, numéro masqué (360 px)', (tester) async {
    final semantics = tester.ensureSemantics();
    final sms = FakeSmsSource();
    await openOtp(tester, sms: sms);

    expect(find.text('Vérification'), findsOneWidget);
    expect(find.text('Code envoyé au +237 6•• •• •• 78.'), findsOneWidget);
    expect(find.text('612345678'), findsNothing);
    expect(find.text('Vérifier'), findsOneWidget);
    for (var i = 1; i <= 6; i++) {
      expect(find.bySemanticsLabel('Chiffre $i sur 6'), findsOneWidget);
      expect(find.byKey(ValueKey('otp-box-${i - 1}')), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Code de vérification'), findsOneWidget);
    expect(tester.widget<TextField>(otpField).keyboardType, TextInputType.number);
    expect(tester.widget<TextField>(otpField).autofocus, isTrue);
    expect(_verifyButton(tester).onPressed, isNull);
    expect(sms.started, isTrue, reason: 'lecture automatique du SMS démarrée');
    expectNoHorizontalScroll(tester);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('les chiffres saisis apparaissent dans les cases ; lettres refusées', (tester) async {
    await openOtp(tester);

    await tester.enterText(otpField, '12a34');
    await tester.pump();

    expect(tester.widget<TextField>(otpField).controller!.text, '1234');
    for (final (i, d) in ['1', '2', '3', '4'].indexed) {
      expect(
        find.descendant(of: find.byKey(ValueKey('otp-box-$i')), matching: find.text(d)),
        findsOneWidget,
      );
    }
    expect(_verifyButton(tester).onPressed, isNull);
  });

  testWidgets('envoi automatique dès le 6e chiffre : connexion et arrivée à l\'Accueil', (tester) async {
    final repo = await openOtp(tester);

    await tester.enterText(otpField, '12345');
    await tester.pump();
    expect(repo.verifiedCodes, isEmpty, reason: '5 chiffres : rien n\'est envoyé');

    await tester.enterText(otpField, '123456');
    await tester.pumpAndSettle();

    expect(repo.verifiedCodes, ['123456']);
    expect(_loggedIn(), isTrue);
    expect(find.byType(OtpScreen), findsNothing);
  });

  testWidgets('collage d\'un SMS entier : le code de 6 chiffres est trouvé et envoyé', (tester) async {
    final repo = await openOtp(tester);

    await tester.enterText(otpField, 'Votre code NetBuis : 482913. Valable 5 min.');
    await tester.pumpAndSettle();

    expect(repo.verifiedCodes, ['482913']);
    expect(_loggedIn(), isTrue);
  });

  testWidgets('lecture automatique du SMS : le code reçu est envoyé', (tester) async {
    final sms = FakeSmsSource();
    final repo = await openOtp(tester, sms: sms);

    sms.receive('<#> 654321 est votre code NetBuis');
    await tester.pumpAndSettle();

    expect(repo.verifiedCodes, ['654321']);
    expect(_loggedIn(), isTrue);
  });

  testWidgets('un SMS sans code de 6 chiffres est ignoré', (tester) async {
    final sms = FakeSmsSource();
    final repo = await openOtp(tester, sms: sms);

    sms.receive('Bienvenue 1234');
    await tester.pumpAndSettle();

    expect(repo.verifiedCodes, isEmpty);
    expect(find.byType(OtpScreen), findsOneWidget);
  });

  testWidgets('le bouton Vérifier envoie le code complet', (tester) async {
    final repo = await openOtp(tester);
    await tester.enterText(otpField, '12345');
    await tester.pump();
    expect(_verifyButton(tester).onPressed, isNull);
    // Sur le 6e chiffre l'envoi est déjà automatique : on vérifie le bouton après une erreur réseau.
    repo.verifyErrors.add(const ApiException(ApiErrorCode.network));
    await tester.enterText(otpField, '123456');
    await tester.pumpAndSettle();

    expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'), findsOneWidget);
    expect(tester.widget<TextField>(otpField).controller!.text, '123456', reason: 'le code reste');
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();

    expect(repo.verifiedCodes, ['123456', '123456']);
    expect(_loggedIn(), isTrue);
  });

  testWidgets('code faux : « Code incorrect », saisie vidée, on peut retaper', (tester) async {
    final repo = await openOtp(tester);
    repo.verifyErrors.add(const ApiException(ApiErrorCode.otpInvalid, message: 'texte du serveur'));

    await tester.enterText(otpField, '000000');
    await tester.pumpAndSettle();

    expect(find.text('Code incorrect'), findsOneWidget);
    expect(find.text('texte du serveur'), findsNothing);
    expect(find.byType(OtpScreen), findsOneWidget);
    expect(tester.widget<TextField>(otpField).controller!.text, '');

    await tester.enterText(otpField, '123456');
    await tester.pumpAndSettle();
    expect(find.text('Code incorrect'), findsNothing);
    expect(_loggedIn(), isTrue);
  });

  testWidgets('retaper un chiffre efface le message d\'erreur', (tester) async {
    final repo = await openOtp(tester);
    repo.verifyErrors.add(const ApiException(ApiErrorCode.otpInvalid));
    await tester.enterText(otpField, '000000');
    await tester.pumpAndSettle();
    expect(find.text('Code incorrect'), findsOneWidget);

    await tester.enterText(otpField, '1');
    await tester.pump();
    expect(find.text('Code incorrect'), findsNothing);
  });

  testWidgets('code expiré : « Code expiré »', (tester) async {
    final repo = await openOtp(tester);
    repo.verifyErrors.add(const ApiException(ApiErrorCode.otpExpired));

    await tester.enterText(otpField, '123456');
    await tester.pumpAndSettle();

    expect(find.text('Code expiré'), findsOneWidget);
    expect(find.byType(OtpScreen), findsOneWidget);
  });

  testWidgets('trop d\'essais : durée de Retry-After (1 h) ; sans durée : message général', (tester) async {
    final repo = await openOtp(tester);
    repo.verifyErrors
      ..add(const ApiException(ApiErrorCode.tooManyRequests, retryAfter: Duration(hours: 1)))
      ..add(const ApiException(ApiErrorCode.tooManyRequests));

    await tester.enterText(otpField, '111111');
    await tester.pumpAndSettle();
    expect(find.text('Trop d\'essais, réessayez dans 1 h'), findsOneWidget);

    await tester.enterText(otpField, '222222');
    await tester.pumpAndSettle();
    expect(find.text('Trop d\'essais, réessayez plus tard'), findsOneWidget);
  });

  testWidgets('compte bloqué ou supprimé : « Contactez le support »', (tester) async {
    final repo = await openOtp(tester);
    repo.verifyErrors
      ..add(const ApiException(ApiErrorCode.accountBlocked, message: 'Contactez le support'))
      ..add(const ApiException(ApiErrorCode.accountDeleted));

    await tester.enterText(otpField, '111111');
    await tester.pumpAndSettle();
    expect(find.text('Contactez le support'), findsOneWidget);

    await tester.enterText(otpField, '222222');
    await tester.pumpAndSettle();
    expect(find.text('Contactez le support'), findsOneWidget);
    expect(_loggedIn(), isFalse);
  });

  group('Renvoyer le code', () {
    testWidgets('compte à rebours de 30 s, puis le bouton s\'active', (tester) async {
      final repo = await openOtp(tester);

      expect(find.text('Renvoyer le code dans 30 s'), findsOneWidget);
      var button = tester.widget<TextButton>(find.byKey(const ValueKey('otp-resend')));
      expect(button.onPressed, isNull);

      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Renvoyer le code dans 20 s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Renvoyer le code'), findsOneWidget);
      button = tester.widget<TextButton>(find.byKey(const ValueKey('otp-resend')));
      expect(button.onPressed, isNotNull);
      expect(tester.getSize(find.byKey(const ValueKey('otp-resend'))).height, greaterThanOrEqualTo(48));

      await tester.tap(find.text('Renvoyer le code'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(repo.requestedPhones, ['+237612345678', '+237612345678']);
    });

    testWidgets('avant la fin du compte à rebours, rien n\'est renvoyé', (tester) async {
      final repo = await openOtp(tester);

      await tester.tap(find.byKey(const ValueKey('otp-resend')), warnIfMissed: false);
      await tester.pump();

      expect(repo.requestedPhones.length, 1);
    });

    testWidgets('un nouveau code relance le compte à rebours et vide la saisie', (tester) async {
      await openOtp(tester);
      await tester.enterText(otpField, '123');
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      await tester.tap(find.text('Renvoyer le code'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Renvoyer le code dans 30 s'), findsOneWidget);
      expect(tester.widget<TextField>(otpField).controller!.text, '');
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });

    testWidgets('trop de demandes : message avec durée, on reste sur l\'écran du code', (tester) async {
      final repo = await openOtp(tester);
      await tester.pump(const Duration(seconds: 30));
      repo.requestErrors.add(
        const ApiException(ApiErrorCode.tooManyRequests, retryAfter: Duration(minutes: 10)),
      );

      await tester.tap(find.text('Renvoyer le code'));
      await tester.pumpAndSettle();

      expect(find.text('Trop d\'essais, réessayez dans 10 min'), findsOneWidget);
      expect(find.byType(OtpScreen), findsOneWidget);
      // Le code déjà reçu reste utilisable.
      await tester.enterText(otpField, '123456');
      await tester.pumpAndSettle();
      expect(_loggedIn(), isTrue);
    });
  });

  testWidgets('retour : revient au numéro, qui reste affiché', (tester) async {
    await openOtp(tester);

    await tester.tap(find.byKey(const ValueKey('auth-back')));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(OtpScreen), findsNothing);
    expect(tester.widget<TextField>(phoneField).controller!.text, '6 12 34 56 78');
  });

  testWidgets('le bouton retour système revient au numéro', (tester) async {
    await openOtp(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('police 130 % à 360 px : pas de débordement, cibles >= 48 dp, pas de défilement horizontal',
      (tester) async {
    await openOtp(tester, textScale: 1.3);

    expect(tester.takeException(), isNull);
    expectNoHorizontalScroll(tester);
    expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(otpField).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(find.byKey(const ValueKey('auth-back'))).height, greaterThanOrEqualTo(48));
    await tester.enterText(otpField, '1234');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
