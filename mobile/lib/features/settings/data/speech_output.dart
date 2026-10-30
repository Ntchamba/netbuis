import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Lecture à voix haute (synthèse vocale du téléphone, décision D-21).
///
/// Règle : jamais d'erreur visible. Sans voix pour la langue de l'application, les boutons
/// « Écouter » sont masqués.
abstract class SpeechOutput {
  /// Vrai pendant qu'un texte est lu.
  ValueListenable<bool> get speaking;

  /// Vrai si une voix existe pour [languageTag] (`fr-FR`, `en-US`) ; pour une langue sans région
  /// exacte (ex. `en-GB` pour `en-US`), toute voix de la même langue suffit. Faux aussi si la
  /// détection échoue.
  Future<bool> hasVoice(String languageTag);

  /// Lit [text] dans la langue [languageTag] (`fr-FR`, `en-US`). Silencieux si impossible.
  Future<void> speak(String text, {required String languageTag});

  /// Arrête la lecture en cours (sans effet s'il n'y en a pas).
  Future<void> stop();
}

/// Version réelle, sur `flutter_tts`. Le moteur n'est créé qu'au premier besoin.
class FlutterTtsSpeechOutput implements SpeechOutput {
  FlutterTtsSpeechOutput({FlutterTts Function()? create}) : _create = create ?? FlutterTts.new;

  static const frenchTag = 'fr-FR';
  static const englishTag = 'en-US';

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

  Future<bool> _available(FlutterTts tts, String tag) async {
    final result = await tts.isLanguageAvailable(tag);
    return result == true || result == 1;
  }

  /// Étiquette réellement utilisable : [tag] lui-même, sinon une autre région de la même langue
  /// (`en-US` absent mais `en-GB` présent). `null` : aucune voix.
  Future<String?> _usableTag(FlutterTts tts, String tag) async {
    if (await _available(tts, tag)) return tag;
    final language = tag.split(RegExp('[-_]')).first.toLowerCase();
    final all = await tts.getLanguages;
    if (all is! List) return null;
    for (final item in all) {
      if (item is! String) continue;
      final parts = item.split(RegExp('[-_]'));
      if (parts.first.toLowerCase() != language) continue;
      if (await _available(tts, item)) return item;
    }
    return null;
  }

  @override
  Future<bool> hasVoice(String languageTag) async {
    try {
      return await _usableTag(_engine(), languageTag) != null;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> speak(String text, {required String languageTag}) async {
    try {
      final tts = _engine();
      final usable = await _usableTag(tts, languageTag);
      if (usable == null) {
        _speaking.value = false;
        return;
      }
      await tts.setLanguage(usable);
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
