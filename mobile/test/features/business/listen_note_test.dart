import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/l10n/l10n.dart';
import 'package:netbuis/core/theme/app_theme.dart';
import 'package:netbuis/features/business/application/business_services.dart';
import 'package:netbuis/features/business/presentation/screens/business_info_screen.dart';
import 'package:netbuis/features/business/presentation/widgets/listen_note.dart';

import '../account/account_test_helpers.dart';
import '../auth/login_test_helpers.dart';
import 'business_test_helpers.dart';

Finder get _listen => find.byKey(const ValueKey('business-listen'));
Finder get _banner => find.byKey(const ValueKey('business-listening'));
String _noteText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('business-note-text'))).data!;

void main() {
  testWidgets('🔊 Écouter lit le texte de l\'encart tel qu\'affiché, en fr-FR', (tester) async {
    final speech = FakeSpeechService();
    await pumpBusinessApp(tester, speech: speech);
    expect(find.text('Écouter'), findsOneWidget);
    expect(_banner, findsNothing);

    await tester.tap(_listen);
    await tester.pump();

    expect(speech.spoken.length, 1);
    expect(speech.spoken.single.text, _noteText(tester));
    expect(speech.spoken.single.text, startsWith('Commerce : pour une boutique'));
    expect(speech.spoken.single.languageTag, 'fr-FR');
    expect(find.text('Lecture audio en cours...'), findsOneWidget);
  });

  testWidgets('le texte lu suit le type choisi', (tester) async {
    final speech = FakeSpeechService();
    await pumpBusinessApp(tester, speech: speech);

    await tester.tap(typeButton('structure'));
    await tester.pumpAndSettle();
    await tester.tap(_listen);
    await tester.pump();

    expect(speech.spoken.single.text, _noteText(tester));
    expect(speech.spoken.single.text, startsWith('Structure : pour un supermarché'));
  });

  testWidgets('rappuyer arrête la lecture', (tester) async {
    final speech = FakeSpeechService();
    await pumpBusinessApp(tester, speech: speech);
    await tester.tap(_listen);
    await tester.pump();
    final stopsBefore = speech.stops;

    await tester.tap(_listen);
    await tester.pump();

    expect(speech.stops, stopsBefore + 1);
    expect(speech.spoken.length, 1);
    expect(_banner, findsNothing);
    expect(find.bySemanticsLabel('Écouter cette explication'), findsOneWidget);
  });

  testWidgets('changer de type pendant la lecture l\'arrête', (tester) async {
    final speech = FakeSpeechService();
    await pumpBusinessApp(tester, speech: speech);
    await tester.tap(_listen);
    await tester.pump();
    expect(_banner, findsOneWidget);

    await tester.tap(typeButton('entreprise'));
    await tester.pumpAndSettle();

    expect(_banner, findsNothing);
    expect(speech.stops, greaterThan(0));
  });

  testWidgets('quitter l\'écran arrête la lecture', (tester) async {
    final speech = FakeSpeechService();
    await pumpBusinessApp(tester, speech: speech);
    await tester.tap(_listen);
    await tester.pump();
    final stopsBefore = speech.stops;

    // Retour au Profil (l'écran Informations est fermé).
    await tester.tap(find.byKey(const ValueKey('business-back')));
    await tester.pumpAndSettle();

    expect(find.text('Mon profil'), findsOneWidget);
    expect(speech.stops, greaterThan(stopsBefore));
    expect(speech.speaking.value, isFalse);
  });

  testWidgets('« Continuer » valide arrête la lecture avant de changer d\'écran', (tester) async {
    final speech = FakeSpeechService();
    await pumpBusinessApp(tester, speech: speech);
    await tester.enterText(find.byKey(const ValueKey('business-name')), 'Chez Aïcha');
    await tester.enterText(find.byKey(const ValueKey('business-owner')), 'Aïcha B.');
    await tester.ensureVisible(find.byKey(const ValueKey('business-owner-photo')));
    await tester.tap(find.byKey(const ValueKey('business-owner-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photo-camera')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(typeButton('entreprise'));
    await tester.tap(typeButton('entreprise'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_listen);
    await tester.tap(_listen);
    await tester.pump();
    expect(speech.speaking.value, isTrue);
    final stopsBefore = speech.stops;

    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Étape 2 sur 5'), findsOneWidget);
    expect(speech.stops, greaterThan(stopsBefore));
    expect(speech.speaking.value, isFalse);
  });

  testWidgets('moteur ou langue indisponible : repli silencieux, aucune erreur ni bandeau',
      (tester) async {
    final speech = FakeSpeechService()..available = false;
    await pumpBusinessApp(tester, speech: speech);

    await tester.tap(_listen);
    await tester.pump();

    expect(speech.spoken, isEmpty);
    expect(_banner, findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
    // Le bouton reste utilisable.
    expect(_listen, findsOneWidget);
  });

  testWidgets('bouton Écouter : cible d\'au moins 48 dp et libellé pour lecteur d\'écran',
      (tester) async {
    await pumpBusinessApp(tester, textScale: 1.3);
    final size = tester.getSize(_listen);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel('Écouter cette explication'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en anglais : textes anglais et synthèse en en-US', (tester) async {
    final speech = FakeSpeechService();
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speechServiceProvider.overrideWithValue(speech),
          photoPickerProvider.overrideWithValue(FakePhotoPicker()),
          accountRepositoryProvider.overrideWithValue(ScriptedAccountRepository(me: meWith())),
          appPrefsProvider.overrideWithValue(MemoryPrefs(seen: true)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: const BusinessInfoScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create my business account'), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Basic information'), findsOneWidget);
    expect(find.text('Shop name'), findsOneWidget);
    expect(find.text('Listen'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(_listen);
    await tester.pump();
    expect(speech.spoken.single.languageTag, 'en-US');
    expect(speech.spoken.single.text, startsWith('Shop: for a shop'));
    expect(find.text('Playing audio...'), findsOneWidget);
    expect(find.byType(ListenNote), findsOneWidget);
  });
}
