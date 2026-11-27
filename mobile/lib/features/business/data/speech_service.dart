import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Lecture à voix haute d'un texte par la synthèse vocale du téléphone.
///
/// Règle d'accessibilité (spec/ACCESSIBILITE.md, principe 10) : si le moteur ou la
/// langue manque, **rien ne se passe** — pas d'erreur, pas de message bloquant.
abstract class SpeechService {
  /// Vrai pendant qu'un texte est lu.
  ValueListenable<bool> get speaking;

  /// Lit [text] dans la langue [languageTag] (ex. `fr-FR`, `en-US`). Silencieux si impossible.
  Future<void> speak(String text, {required String languageTag});

  /// Arrête la lecture en cours (sans effet s'il n'y en a pas).
  Future<void> stop();
}

/// Version réelle, sur le paquet `flutter_tts` (moteur du téléphone). Le moteur n'est
/// créé qu'à la première lecture. Toute exception est avalée : repli silencieux.
class FlutterTtsSpeechService implements SpeechService {
  FlutterTtsSpeechService({FlutterTts Function()? create}) : _create = create ?? FlutterTts.new;

  final FlutterTts Function() _create;
  FlutterTts? _tts;
  final ValueNotifier<bool> _speaking = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get speaking => _speaking;

  FlutterTts _engine() {
    final existing = _tts;
    if (existing != null) return existing;
    final tts = _create();
    void ended() => _speaking.value = false;
    tts.setCompletionHandler(ended);
    tts.setCancelHandler(ended);
    tts.setErrorHandler((Object? _) => ended());
    return _tts = tts;
  }

  @override
  Future<void> speak(String text, {required String languageTag}) async {
    try {
      final tts = _engine();
      if (await tts.isLanguageAvailable(languageTag) != true) {
        _speaking.value = false;
        return;
      }
      await tts.setLanguage(languageTag);
      _speaking.value = true;
      await tts.speak(text);
    } on Object {
      _speaking.value = false;
    }
  }

  @override
  Future<void> stop() async {
    _speaking.value = false;
    final tts = _tts;
    if (tts == null) return;
    try {
      await tts.stop();
    } on Object {
      // Rien à arrêter ou moteur absent : sans importance.
    }
  }
}
