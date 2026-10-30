import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/l10n/l10n.dart';
import 'package:netbuis/features/account/presentation/screens/edit_profile_screen.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/auth/application/auth_state.dart';
import 'package:netbuis/features/auth/data/repositories/auth_repository_fake.dart';
import 'package:netbuis/features/auth/presentation/screens/login_screen.dart';
import 'package:netbuis/features/auth/presentation/screens/otp_screen.dart';
import 'package:netbuis/features/auth/presentation/widgets/auth_messages.dart';
import 'package:netbuis/features/onboarding/presentation/screens/onboarding_screen.dart';

import 'login_test_helpers.dart';

bool _onHome() => find.byType(NavigationDestination).evaluate().length == 4;

void main() {
  testWidgets('parcours complet en mode fake : Lancement, Découverte, numéro, code, Accueil', (tester) async {
    await pumpAuthApp(
      tester,
      repository: AuthRepositoryFake(),
      initialLocation: Routes.splash,
      onboardingSeen: false,
    );

    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await submitPhone(tester, '612345678');
    expect(find.byType(OtpScreen), findsOneWidget);

    await tester.enterText(otpField, AuthRepositoryFake.acceptedCode);
    await tester.pumpAndSettle();

    // Première connexion : l'écran du nom est proposé avant l'Accueil.
    expect(find.byType(EditProfileScreen), findsOneWidget);
    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();

    expect(_onHome(), isTrue);
    expect(find.byType(OtpScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('parcours avec le faux serveur : code faux puis bon code', (tester) async {
    await pumpAuthApp(tester, repository: AuthRepositoryFake());
    await submitPhone(tester, '612345678');

    await tester.enterText(otpField, '000000');
    await tester.pumpAndSettle();
    expect(find.text('Code incorrect'), findsOneWidget);
    expect(find.byType(OtpScreen), findsOneWidget);
    expect(_onHome(), isFalse);

    await tester.enterText(otpField, AuthRepositoryFake.acceptedCode);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();
    expect(_onHome(), isTrue);
  });

  testWidgets('parcours « trop d\'essais » : message, puis bloqué sans entrer', (tester) async {
    final repo = FlowRepository()
      ..verifyErrors.addAll([
        const ApiException(ApiErrorCode.otpInvalid),
        const ApiException(ApiErrorCode.tooManyRequests, retryAfter: Duration(minutes: 45)),
      ]);
    await pumpAuthApp(tester, repository: repo);
    await submitPhone(tester, '612345678');

    await tester.enterText(otpField, '111111');
    await tester.pumpAndSettle();
    expect(find.text('Code incorrect'), findsOneWidget);

    await tester.enterText(otpField, '222222');
    await tester.pumpAndSettle();
    expect(find.text('Trop d\'essais, réessayez dans 45 min'), findsOneWidget);
    expect(_onHome(), isFalse);
    expect(find.byType(OtpScreen), findsOneWidget);
  });

  testWidgets('session restaurée : la connexion mène directement à l\'Accueil', (tester) async {
    await pumpAuthApp(tester, repository: FlowRepository(), signedIn: true);

    expect(_onHome(), isTrue);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('non connecté : l\'Accueil n\'est pas accessible', (tester) async {
    await pumpAuthApp(tester, repository: FlowRepository(), initialLocation: Routes.home);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(_onHome(), isFalse);
  });

  testWidgets('l\'écran du code sans code envoyé renvoie au numéro', (tester) async {
    await pumpAuthApp(tester, repository: FlowRepository(), initialLocation: Routes.otp);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(OtpScreen), findsNothing);
  });

  testWidgets('l\'écran provisoire fake-login n\'existe plus', (tester) async {
    await pumpAuthApp(tester, repository: FlowRepository(), initialLocation: '/fake-login');

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('fake', findRichText: true), findsNothing);
  });

  group('messages d\'erreur dans les deux langues', () {
    Map<String, String> read(String lang) =>
        (json.decode(File('assets/l10n/$lang.json').readAsStringSync()) as Map<String, dynamic>)
            .cast<String, String>();

    final cases = <(ApiErrorCode, Duration?, String, String)>[
      (ApiErrorCode.invalidPhone, null, 'Numéro invalide : 9 chiffres commençant par 6.', 'Invalid number: 9 digits starting with 6.'),
      (ApiErrorCode.otpInvalid, null, 'Code incorrect', 'Wrong code'),
      (ApiErrorCode.otpExpired, null, 'Code expiré', 'Code expired'),
      (ApiErrorCode.tooManyRequests, null, "Trop d'essais, réessayez plus tard", 'Too many attempts, try again later'),
      (ApiErrorCode.tooManyRequests, const Duration(seconds: 45), "Trop d'essais, réessayez dans 45 s", 'Too many attempts, try again in 45 s'),
      (ApiErrorCode.tooManyRequests, const Duration(seconds: 3600), "Trop d'essais, réessayez dans 1 h", 'Too many attempts, try again in 1 h'),
      (ApiErrorCode.accountBlocked, null, 'Contactez le support', 'Contact support'),
      (ApiErrorCode.accountDeleted, null, 'Contactez le support', 'Contact support'),
      (ApiErrorCode.network, null, 'Pas de connexion. Vérifiez votre réseau et réessayez.', 'No connection. Check your network and try again.'),
      (ApiErrorCode.unknown, null, 'Une erreur est survenue. Réessayez.', 'Something went wrong. Try again.'),
    ];

    for (final (code, wait, fr, en) in cases) {
      test('${code.value} ${wait ?? ''}', () {
        final failure = AuthFailure(code, message: 'ignoré', retryAfter: wait);
        expect(authFailureMessage(L10n(const Locale('fr'), read('fr')), failure), fr);
        expect(authFailureMessage(L10n(const Locale('en'), read('en')), failure), en);
      });
    }

    test('le message du serveur n\'est jamais affiché', () {
      final l10n = L10n(const Locale('fr'), read('fr'));
      const failure = AuthFailure(ApiErrorCode.otpInvalid, message: 'message brut du serveur');
      expect(authFailureMessage(l10n, failure), isNot(contains('serveur')));
    });
  });
}
