import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/app.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/business/application/business_draft_controller.dart';
import 'package:netbuis/features/business/application/business_services.dart';
import 'package:netbuis/features/business/data/models/business_draft.dart';
import 'package:netbuis/features/business/data/photo_service.dart';
import 'package:netbuis/features/business/data/speech_service.dart';

import '../account/account_test_helpers.dart';
import '../auth/auth_test_helpers.dart';
import '../auth/login_test_helpers.dart';

/// Synthèse vocale factice : enregistre ce qu'on lui fait lire.
class FakeSpeechService implements SpeechService {
  final ValueNotifier<bool> _speaking = ValueNotifier<bool>(false);
  final List<({String text, String languageTag})> spoken = [];
  int stops = 0;

  /// Faux = moteur ou langue indisponible : la lecture ne démarre pas, sans erreur.
  bool available = true;

  @override
  ValueListenable<bool> get speaking => _speaking;

  @override
  Future<void> speak(String text, {required String languageTag}) async {
    if (!available) return;
    spoken.add((text: text, languageTag: languageTag));
    _speaking.value = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    _speaking.value = false;
  }
}

/// Appareil photo factice : renvoie un chemin fictif (ou null = annulé, ou lève une erreur).
class FakePhotoPicker implements PhotoPickerService {
  String? result = '/fictif/photo.jpg';
  bool fail = false;
  final List<PhotoSource> asked = [];

  @override
  Future<String?> pick(PhotoSource source) async {
    asked.add(source);
    if (fail) throw StateError('appareil photo inaccessible');
    return result;
  }
}

/// Lance l'application complète à 360 px, connectée, sur l'écran demandé.
Future<void> pumpBusinessApp(
  WidgetTester tester, {
  FakeSpeechService? speech,
  FakePhotoPicker? photos,
  ScriptedAccountRepository? account,
  String initialLocation = Routes.createBusiness,
  bool signedIn = true,
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.dark,
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  // Repart d'une application neuve même si le test relance plusieurs fois l'écran.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountRepositoryProvider
            .overrideWithValue(account ?? ScriptedAccountRepository(me: meWith(name: 'Jeff N.'))),
        authRepositoryProvider.overrideWithValue(FlowRepository()),
        tokenStorageProvider
            .overrideWithValue(MemoryTokenStorage(refresh: signedIn ? 'ref-1' : null)),
        appPrefsProvider.overrideWithValue(MemoryPrefs(seen: true)),
        speechServiceProvider.overrideWithValue(speech ?? FakeSpeechService()),
        photoPickerProvider.overrideWithValue(photos ?? FakePhotoPicker()),
      ],
      child: NetBuisApp(themeMode: mode, initialLocation: initialLocation),
    ),
  );
  await tester.pumpAndSettle();
}

/// Brouillon courant de l'application lancée.
BusinessDraft currentDraft(WidgetTester tester) {
  final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
  return container.read(businessDraftProvider);
}

Finder typeButton(String code) => find.byKey(ValueKey('business-type-$code'));
Finder get continueButton => find.text('Continuer');
