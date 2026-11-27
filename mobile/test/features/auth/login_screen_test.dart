import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/l10n/l10n.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/theme/app_theme.dart';
import 'package:netbuis/features/auth/presentation/screens/login_screen.dart';
import 'package:netbuis/features/auth/presentation/screens/otp_screen.dart';

import 'auth_test_helpers.dart';
import 'login_test_helpers.dart';

const _subtitle =
    'Entrez votre numéro de téléphone pour continuer. Un code de vérification vous sera envoyé par SMS.';
const _terms =
    "En continuant, vous acceptez les conditions d'utilisation et la politique de confidentialité de NetBuis.";

FilledButton _submitButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Recevoir le code'));

void main() {
  testWidgets('étape numéro : textes de la maquette, préfixe, clavier numérique (360 px)', (tester) async {
    await pumpAuthApp(tester, repository: FlowRepository());

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text(_subtitle), findsOneWidget);
    expect(find.text('🇨🇲 +237'), findsOneWidget);
    expect(find.text('6XX XX XX XX'), findsOneWidget);
    expect(find.text('Recevoir le code'), findsOneWidget);
    expect(find.text(_terms), findsOneWidget);

    final field = tester.widget<TextField>(phoneField);
    expect(field.keyboardType, TextInputType.number);
    expect(field.autofocus, isTrue);
    expect(_submitButton(tester).onPressed, isNull, reason: 'désactivé tant que le format est faux');
    expectNoHorizontalScroll(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('9 chiffres commençant par 6 : formaté et bouton actif', (tester) async {
    await pumpAuthApp(tester, repository: FlowRepository());

    await tester.enterText(phoneField, '61234567');
    await tester.pump();
    expect(_submitButton(tester).onPressed, isNull);

    await tester.enterText(phoneField, '612345678');
    await tester.pump();
    expect(tester.widget<TextField>(phoneField).controller!.text, '6 12 34 56 78');
    expect(_submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('numéro qui ne commence pas par 6 : message court et bouton inactif', (tester) async {
    await pumpAuthApp(tester, repository: FlowRepository());

    await tester.enterText(phoneField, '512345678');
    await tester.pump();

    expect(find.text('Numéro invalide : 9 chiffres commençant par 6.'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNull);
  });

  testWidgets('lettres refusées, collage avec indicatif accepté', (tester) async {
    await pumpAuthApp(tester, repository: FlowRepository());

    await tester.enterText(phoneField, 'abc');
    await tester.pump();
    expect(tester.widget<TextField>(phoneField).controller!.text, '');

    await tester.enterText(phoneField, '+237 6 12 34 56 78');
    await tester.pump();
    expect(tester.widget<TextField>(phoneField).controller!.text, '6 12 34 56 78');
    expect(_submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('Recevoir le code envoie +237 et les 9 chiffres, puis ouvre l\'écran du code', (tester) async {
    final repo = FlowRepository();
    await pumpAuthApp(tester, repository: repo);

    await submitPhone(tester, '612345678');

    expect(repo.requestedPhones, ['+237612345678']);
    expect(find.byType(OtpScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('le serveur refuse le numéro : message, on reste sur l\'écran', (tester) async {
    final repo = FlowRepository()
      ..requestErrors.add(const ApiException(ApiErrorCode.invalidPhone, message: 'texte du serveur'));
    await pumpAuthApp(tester, repository: repo);

    await submitPhone(tester, '612345678');

    expect(find.text('Numéro invalide : 9 chiffres commençant par 6.'), findsOneWidget);
    expect(find.text('texte du serveur'), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('trop de demandes : la durée de Retry-After est affichée', (tester) async {
    final repo = FlowRepository()
      ..requestErrors.add(
        const ApiException(ApiErrorCode.tooManyRequests, retryAfter: Duration(minutes: 10)),
      );
    await pumpAuthApp(tester, repository: repo);

    await submitPhone(tester, '612345678');
    expect(find.text('Trop d\'essais, réessayez dans 10 min'), findsOneWidget);

    // Retaper efface le message.
    await tester.enterText(phoneField, '61234567');
    await tester.pump();
    expect(find.textContaining('Trop d\'essais'), findsNothing);
  });

  testWidgets('trop de demandes sans durée : message général', (tester) async {
    final repo = FlowRepository()..requestErrors.add(const ApiException(ApiErrorCode.tooManyRequests));
    await pumpAuthApp(tester, repository: repo);

    await submitPhone(tester, '612345678');
    expect(find.text('Trop d\'essais, réessayez plus tard'), findsOneWidget);
  });

  testWidgets('réseau coupé : message simple, puis on peut réessayer', (tester) async {
    final repo = FlowRepository()..requestErrors.add(const ApiException(ApiErrorCode.network));
    await pumpAuthApp(tester, repository: repo);

    await submitPhone(tester, '612345678');
    expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Recevoir le code'));
    await tester.pumpAndSettle();
    expect(repo.requestedPhones.length, 2);
    expect(find.byType(OtpScreen), findsOneWidget);
  });

  testWidgets('police 130 % à 360 px : pas de débordement, cibles >= 48 dp', (tester) async {
    await pumpAuthApp(tester, repository: FlowRepository(), textScale: 1.3);

    expect(tester.takeException(), isNull);
    expectNoHorizontalScroll(tester);
    expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(phoneField).height, greaterThanOrEqualTo(48));
  });

  testWidgets('accessibilité : champ et préfixe ont un libellé', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpAuthApp(tester, repository: FlowRepository());

    expect(find.bySemanticsLabel(RegExp('Numéro de téléphone')), findsOneWidget);
    expect(find.bySemanticsLabel('Indicatif du Cameroun, plus 237'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('anglais : tous les textes de l\'étape numéro sont traduits', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FlowRepository()),
          tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: L10n.supportedLocales,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Get the code'), findsOneWidget);
    expect(find.textContaining('terms of use'), findsOneWidget);
    expect(find.text('Connexion'), findsNothing);
  });
}
