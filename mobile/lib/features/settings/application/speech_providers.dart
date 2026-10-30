import 'package:flutter/widgets.dart';
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

/// Étiquette de langue vocale de l'application : `fr-FR` en français, `en-US` en anglais.
final speechLanguageTagProvider = Provider<String>((ref) {
  final language = ref.watch(settingsControllerProvider.select((s) => s.language));
  return language == 'en' ? FlutterTtsSpeechOutput.englishTag : FlutterTtsSpeechOutput.frenchTag;
});

/// Compteur relancé quand l'application revient au premier plan : une voix installée pendant
/// l'usage doit apparaître sans redémarrer.
final voiceRefreshProvider = NotifierProvider<VoiceRefresh, int>(VoiceRefresh.new);

class VoiceRefresh extends Notifier<int> {
  @override
  int build() {
    final observer = _ResumeObserver(() => state++);
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
    return 0;
  }
}

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this.onResumed);

  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }
}

/// Existe-t-il une voix pour la langue [tag] ? Mesuré par langue (un changement de langue repart
/// de « inconnu » donc masqué) et remesuré à chaque reprise de l'application ; faux si la
/// détection échoue.
final voiceAvailableProvider = FutureProvider.family<bool, String>((ref, tag) async {
  ref.watch(voiceRefreshProvider);
  try {
    return await ref.read(speechOutputProvider).hasVoice(tag);
  } on Object {
    return false;
  }
});
