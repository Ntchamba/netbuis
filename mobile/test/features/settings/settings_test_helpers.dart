import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/app.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/auth/data/repositories/auth_repository.dart';
import 'package:netbuis/features/settings/application/settings_controller.dart';
import 'package:netbuis/features/settings/application/speech_providers.dart';
import 'package:netbuis/features/settings/data/settings_store.dart';
import 'package:netbuis/features/settings/data/speech_output.dart';

import '../account/account_test_helpers.dart';
import '../auth/auth_test_helpers.dart';
import '../auth/login_test_helpers.dart';

/// Mémoire des réglages en RAM ; [failing] simule un stockage en panne (comme le vrai : sans erreur).
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore({this.stored = const AppSettings(), this.failing = false});

  AppSettings stored;
  bool failing;
  int saves = 0;

  @override
  Future<AppSettings> load() async => failing ? const AppSettings() : stored;

  @override
  Future<void> save(AppSettings settings) async {
    saves++;
    if (!failing) stored = settings;
  }
}

/// Faux service vocal : on choisit si une voix française existe, ou si la détection échoue.
class FakeSpeechOutput implements SpeechOutput {
  FakeSpeechOutput({this.french = true, this.detectionFails = false});

  bool french;
  bool detectionFails;
  final List<String> spoken = [];
  final List<String> tags = [];
  int stops = 0;
  final ValueNotifier<bool> _speaking = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get speaking => _speaking;

  @override
  Future<bool> hasFrenchVoice() async {
    if (detectionFails) throw StateError('moteur absent');
    return french;
  }

  @override
  Future<void> speak(String text, {required String languageTag}) async {
    spoken.add(text);
    tags.add(languageTag);
    _speaking.value = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    _speaking.value = false;
  }
}

/// Lance l'application complète à 360 px (sans thème imposé : ce sont les réglages qui décident).
Future<void> pumpSettingsApp(
  WidgetTester tester, {
  required MemorySettingsStore store,
  FakeSpeechOutput? speech,
  AuthRepository? auth,
  String initialLocation = Routes.settings,
  bool signedIn = true,
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountRepositoryProvider.overrideWithValue(ScriptedAccountRepository()),
        authRepositoryProvider.overrideWithValue(auth ?? FlowRepository()),
        tokenStorageProvider
            .overrideWithValue(MemoryTokenStorage(refresh: signedIn ? 'ref-1' : null)),
        appPrefsProvider.overrideWithValue(MemoryPrefs(seen: true)),
        settingsStoreProvider.overrideWithValue(store),
        speechOutputProvider.overrideWithValue(speech ?? FakeSpeechOutput()),
      ],
      child: NetBuisApp(initialLocation: initialLocation),
    ),
  );
  await tester.pumpAndSettle();
}

/// « Ferme » l'application (le conteneur disparaît) ; la suivante repart des mêmes préférences.
Future<void> closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

MaterialApp materialApp(WidgetTester tester) => tester.widget<MaterialApp>(find.byType(MaterialApp));
