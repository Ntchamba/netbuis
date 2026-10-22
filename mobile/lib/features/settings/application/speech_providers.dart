import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/speech_output.dart';
import 'settings_controller.dart';

/// Synthèse vocale du téléphone, remplaçable dans les tests.
final speechOutputProvider = Provider<SpeechOutput>((ref) {
  final service = FlutterTtsSpeechOutput();
  ref.onDispose(service.stop);
  return service;
});

/// Arrête la lecture quand la langue de l'application change (surveillé par la racine).
final speechLanguageGuardProvider = Provider<void>((ref) {
  ref.listen(
    settingsControllerProvider.select((s) => s.language),
    (previous, next) => ref.read(speechOutputProvider).stop(),
  );
});

/// Une voix française est-elle installée ? Mesuré une fois ; faux si la détection échoue.
final frenchVoiceAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.read(speechOutputProvider).hasFrenchVoice();
  } on Object {
    return false;
  }
});
