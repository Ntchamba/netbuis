import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/settings/application/settings_controller.dart';
import 'package:netbuis/features/settings/application/speech_providers.dart';
import 'package:netbuis/features/settings/data/speech_output.dart';

import 'settings_test_helpers.dart';

void main() {
  const listen = ValueKey('listen-button');

  group('bouton Écouter (page légale)', () {
    testWidgets('masqué sans voix française', (tester) async {
      await pumpSettingsApp(tester,
          store: MemorySettingsStore(),
          speech: FakeSpeechOutput(french: false),
          initialLocation: Routes.terms);
      expect(find.byKey(listen), findsNothing);
      expect(find.text('Écouter'), findsNothing);
    });

    testWidgets('masqué si la détection échoue', (tester) async {
      await pumpSettingsApp(tester,
          store: MemorySettingsStore(),
          speech: FakeSpeechOutput(detectionFails: true),
          initialLocation: Routes.terms);
      expect(find.byKey(listen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('visible avec une voix française, lit le texte affiché, puis s\'arrête',
        (tester) async {
      final speech = FakeSpeechOutput();
      await pumpSettingsApp(tester,
          store: MemorySettingsStore(), speech: speech, initialLocation: Routes.terms);
      expect(find.byKey(listen), findsOneWidget);
      final shown = tester.widget<Text>(find.byKey(const ValueKey('legal-body'))).data;

      await tester.tap(find.byKey(listen));
      await tester.pumpAndSettle();
      expect(speech.spoken, [shown]);
      expect(speech.tags, ['fr-FR']);
      expect(find.text('Arrêter'), findsOneWidget);

      await tester.tap(find.byKey(listen));
      await tester.pumpAndSettle();
      expect(speech.stops, 1);
      expect(find.text('Écouter'), findsOneWidget);
    });

    testWidgets('la lecture s\'arrête quand on quitte l\'écran', (tester) async {
      final speech = FakeSpeechOutput();
      await pumpSettingsApp(tester,
          store: MemorySettingsStore(), speech: speech, initialLocation: Routes.terms);
      await tester.tap(find.byKey(listen));
      await tester.pumpAndSettle();
      expect(speech.speaking.value, isTrue);
      await tester.tap(find.byKey(const ValueKey('settings-back')));
      await tester.pumpAndSettle();
      expect(speech.speaking.value, isFalse);
    });
  });

  test('la lecture s\'arrête au changement de langue (réglages)', () async {
    final speech = FakeSpeechOutput();
    final store = MemorySettingsStore();
    final container = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(store),
      speechOutputProvider.overrideWithValue(speech),
    ]);
    addTearDown(container.dispose);
    container.read(speechLanguageGuardProvider);
    await speech.speak('Bonjour', languageTag: 'fr-FR');
    expect(speech.speaking.value, isTrue);

    container.read(settingsControllerProvider.notifier).setLanguage('en');

    expect(speech.speaking.value, isFalse);
    expect(speech.stops, 1);
    // Choisir le thème ne coupe pas la lecture.
    await speech.speak('Bonjour', languageTag: 'fr-FR');
    container.read(settingsControllerProvider.notifier).setThemeMode(ThemeMode.dark);
    expect(speech.speaking.value, isTrue);
  });

  group('FlutterTtsSpeechOutput (moteur simulé)', () {
    const channel = MethodChannel('flutter_tts');
    final calls = <MethodCall>[];

    void mockEngine(Future<Object?> Function(MethodCall call) handler) {
      TestWidgetsFlutterBinding.ensureInitialized();
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        return handler(call);
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
    }

    test('voix française installée : vrai', () async {
      mockEngine((call) async => call.method == 'isLanguageAvailable' ? true : 1);
      expect(await FlutterTtsSpeechOutput().hasVoice('fr-FR'), isTrue);
      expect(calls.first.arguments, 'fr-FR');
    });

    test('pas de voix française : faux', () async {
      mockEngine((call) async => false);
      expect(await FlutterTtsSpeechOutput().hasVoice('fr-FR'), isFalse);
    });

    test('anglais : en-US absent mais en-GB présent : vrai, et lu en en-GB', () async {
      mockEngine((call) async {
        switch (call.method) {
          case 'isLanguageAvailable':
            return call.arguments == 'en-GB';
          case 'getLanguages':
            return ['fr-FR', 'en-GB'];
        }
        return 1;
      });
      final tts = FlutterTtsSpeechOutput();
      expect(await tts.hasVoice('en-US'), isTrue);
      await tts.speak('Hello', languageTag: 'en-US');
      expect(calls.where((c) => c.method == 'setLanguage').single.arguments, 'en-GB');
    });

    test('voix française seule : pas de voix anglaise', () async {
      mockEngine((call) async {
        if (call.method == 'isLanguageAvailable') return call.arguments == 'fr-FR';
        if (call.method == 'getLanguages') return ['fr-FR', 'fr-CA'];
        return 1;
      });
      final tts = FlutterTtsSpeechOutput();
      expect(await tts.hasVoice('en-US'), isFalse);
      expect(await tts.hasVoice('fr-FR'), isTrue);
    });

    test('le moteur plante : faux, sans exception', () async {
      mockEngine((call) async => throw PlatformException(code: 'KO'));
      expect(await FlutterTtsSpeechOutput().hasVoice('fr-FR'), isFalse);
    });

    test('lecture : règle la langue puis lit ; langue indisponible : silence', () async {
      mockEngine((call) async => call.method == 'isLanguageAvailable' ? true : 1);
      final ok = FlutterTtsSpeechOutput();
      await ok.speak('Bonjour', languageTag: 'fr-FR');
      expect(calls.map((c) => c.method), ['isLanguageAvailable', 'setLanguage', 'speak']);
      expect(ok.speaking.value, isTrue);
      await ok.stop();
      expect(ok.speaking.value, isFalse);

      mockEngine((call) async => false);
      final none = FlutterTtsSpeechOutput();
      await none.speak('Bonjour', languageTag: 'fr-FR');
      expect(calls.map((c) => c.method), ['isLanguageAvailable', 'getLanguages']);
      expect(none.speaking.value, isFalse);
    });
  });

}
