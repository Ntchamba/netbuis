// État de la recherche vocale : préparation du micro, écoute, erreurs simples.
// Le texte reconnu part vers la recherche (POST /api/search/voice/ via SearchController).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/search_controller.dart';
import '../data/speech_service.dart';

enum VoicePhase {
  /// Rien en cours.
  idle,

  /// Autorisation du micro / démarrage du service.
  preparing,

  /// Le téléphone écoute : bandeau « Je vous écoute… ».
  listening,

  /// Échec : voir [VoiceState.error].
  failed,
}

/// Cause d'un échec, traduite en message simple par l'écran.
enum VoiceError { denied, unavailable, noSpeech, failed }

class VoiceState {
  const VoiceState({this.phase = VoicePhase.idle, this.error, this.heard = ''});

  final VoicePhase phase;
  final VoiceError? error;

  /// Texte compris jusqu'ici (partiel pendant l'écoute).
  final String heard;
}

final voiceSearchControllerProvider =
    NotifierProvider<VoiceSearchController, VoiceState>(VoiceSearchController.new);

/// Vrai une fois l'explication sur le micro montrée (pendant cette session de l'appli).
final voiceRationaleSeenProvider =
    NotifierProvider<VoiceRationaleSeen, bool>(VoiceRationaleSeen.new);

class VoiceRationaleSeen extends Notifier<bool> {
  @override
  bool build() => false;

  void markSeen() => state = true;
}

class VoiceSearchController extends Notifier<VoiceState> {
  int _session = 0;

  @override
  VoiceState build() {
    final speech = ref.read(speechServiceProvider);
    ref.onDispose(() {
      _session++;
      speech.cancel();
    });
    return const VoiceState();
  }

  SpeechService get _speech => ref.read(speechServiceProvider);

  /// Demande le micro puis écoute. Ne fait rien si une écoute est déjà en cours.
  Future<void> start() async {
    if (state.phase == VoicePhase.preparing || state.phase == VoicePhase.listening) return;
    final session = ++_session;
    state = const VoiceState(phase: VoicePhase.preparing);
    SpeechAvailability availability;
    try {
      availability = await _speech.prepare();
    } on Object {
      availability = SpeechAvailability.unavailable;
    }
    if (!ref.mounted || session != _session) return;
    switch (availability) {
      case SpeechAvailability.denied:
        return _fail(VoiceError.denied);
      case SpeechAvailability.unavailable:
        return _fail(VoiceError.unavailable);
      case SpeechAvailability.ready:
        break;
    }
    state = const VoiceState(phase: VoicePhase.listening);
    try {
      await _speech.listen(
        onResult: (words, isFinal) => _onResult(session, words, isFinal),
        onError: (failure) => _onFailure(session, failure),
        onDone: () => _onDone(session),
      );
    } on Object {
      if (ref.mounted && session == _session) _fail(VoiceError.failed);
    }
  }

  void _onResult(int session, String words, bool isFinal) {
    if (!ref.mounted || session != _session || state.phase != VoicePhase.listening) return;
    final text = words.trim();
    if (!isFinal) {
      state = VoiceState(phase: VoicePhase.listening, heard: text);
      return;
    }
    if (text.isEmpty) return _fail(VoiceError.noSpeech);
    _session++;
    state = const VoiceState();
    ref.read(searchControllerProvider.notifier).searchByVoice(text);
  }

  void _onFailure(int session, SpeechFailure failure) {
    if (!ref.mounted || session != _session || state.phase != VoicePhase.listening) return;
    _fail(failure.noSpeech ? VoiceError.noSpeech : VoiceError.failed);
  }

  /// Fin d'écoute sans résultat final : on utilise ce qui a été compris, sinon « pas compris ».
  void _onDone(int session) {
    if (!ref.mounted || session != _session || state.phase != VoicePhase.listening) return;
    final text = state.heard.trim();
    if (text.isEmpty) return _fail(VoiceError.noSpeech);
    _onResult(session, text, true);
  }

  /// Touche sur le bandeau : on arrête sans rien chercher.
  Future<void> cancel() async {
    _session++;
    state = const VoiceState();
    await _speech.cancel();
  }

  /// L'écran a montré le message d'erreur.
  void acknowledge() {
    if (state.phase == VoicePhase.failed) state = const VoiceState();
  }

  void _fail(VoiceError error) {
    _session++;
    state = VoiceState(phase: VoicePhase.failed, error: error);
    _speech.cancel();
  }
}
