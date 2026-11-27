// Reconnaissance vocale du téléphone (speech_to_text) derrière une interface,
// pour pouvoir la remplacer par un faux service dans les tests.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Résultat de la préparation du micro.
enum SpeechAvailability {
  /// Micro autorisé et reconnaissance disponible.
  ready,

  /// L'utilisateur a refusé (ou retiré) l'autorisation du micro.
  denied,

  /// Pas de service de reconnaissance vocale sur ce téléphone.
  unavailable,
}

/// Une erreur de reconnaissance ; [noSpeech] = rien d'audible ou rien compris.
class SpeechFailure {
  const SpeechFailure({required this.message, this.noSpeech = false});
  final String message;
  final bool noSpeech;
}

abstract class SpeechService {
  /// Prépare la reconnaissance. Sur Android, cela déclenche la demande d'autorisation du micro.
  Future<SpeechAvailability> prepare();

  /// Écoute en français. [onResult] reçoit le texte (partiel puis final) ;
  /// [onError] une erreur ; [onDone] la fin de l'écoute.
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required void Function(SpeechFailure failure) onError,
    required void Function() onDone,
  });

  /// Arrête l'écoute en gardant ce qui a été compris.
  Future<void> stop();

  /// Abandonne l'écoute.
  Future<void> cancel();
}

/// Langue de la reconnaissance : français (France) par défaut.
const String kSpeechLocale = 'fr_FR';

class SpeechToTextService implements SpeechService {
  SpeechToTextService([SpeechToText? engine]) : _engine = engine ?? SpeechToText();

  final SpeechToText _engine;
  void Function(SpeechFailure)? _onError;
  void Function()? _onDone;
  bool _permissionDenied = false;

  @override
  Future<SpeechAvailability> prepare() async {
    _permissionDenied = false;
    final ok = await _engine.initialize(onError: _handleError, onStatus: _handleStatus);
    if (ok) return SpeechAvailability.ready;
    return _permissionDenied || !(await _engine.hasPermission)
        ? SpeechAvailability.denied
        : SpeechAvailability.unavailable;
  }

  void _handleError(SpeechRecognitionError e) {
    if (e.errorMsg == 'error_permission') _permissionDenied = true;
    final silent = e.errorMsg == 'error_no_match' || e.errorMsg == 'error_speech_timeout';
    _onError?.call(SpeechFailure(message: e.errorMsg, noSpeech: silent));
  }

  void _handleStatus(String status) {
    if (status == 'done' || status == 'notListening') _onDone?.call();
  }

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required void Function(SpeechFailure failure) onError,
    required void Function() onDone,
  }) async {
    _onError = onError;
    _onDone = onDone;
    final locales = await _engine.locales();
    final french = locales.where((l) => l.localeId.toLowerCase().startsWith('fr'));
    final preferred = french.where((l) => l.localeId.replaceAll('-', '_') == kSpeechLocale);
    final locale = preferred.isNotEmpty
        ? preferred.first.localeId
        : (french.isNotEmpty ? french.first.localeId : kSpeechLocale);
    await _engine.listen(
      onResult: (SpeechRecognitionResult r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: locale,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  @override
  Future<void> stop() => _engine.stop();

  @override
  Future<void> cancel() => _engine.cancel();
}

final speechServiceProvider = Provider<SpeechService>((ref) => SpeechToTextService());
