import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:netbuis/features/business/data/speech_service.dart';

/// Teste la vraie classe [FlutterTtsSpeechService] en simulant le moteur du téléphone
/// (canal `flutter_tts`) : aucune voix réelle n'est utilisée.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  final calls = <MethodCall>[];

  void mockEngine(Future<Object?> Function(MethodCall call) handler) {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
  }

  test('langue disponible : règle la langue, lit le texte, puis la fin remet « pas en lecture »',
      () async {
    mockEngine((call) async => call.method == 'isLanguageAvailable' ? true : 1);
    late FlutterTts engine;
    final service = FlutterTtsSpeechService(create: () => engine = FlutterTts());

    await service.speak('Bonjour', languageTag: 'fr-FR');

    expect(calls.map((c) => c.method), ['isLanguageAvailable', 'setLanguage', 'speak']);
    expect(calls[0].arguments, 'fr-FR');
    expect(calls[1].arguments, 'fr-FR');
    expect(calls[2].arguments, 'Bonjour');
    expect(service.speaking.value, isTrue);

    // Le téléphone signale la fin de la lecture.
    await engine.platformCallHandler(const MethodCall('speak.onComplete'));
    expect(service.speaking.value, isFalse);
  });

  test('stop arrête la lecture', () async {
    mockEngine((call) async => call.method == 'isLanguageAvailable' ? true : 1);
    final service = FlutterTtsSpeechService();
    await service.speak('Bonjour', languageTag: 'fr-FR');
    expect(service.speaking.value, isTrue);

    await service.stop();

    expect(service.speaking.value, isFalse);
    expect(calls.last.method, 'stop');
  });

  test('stop sans lecture préalable ne crée pas le moteur et ne plante pas', () async {
    mockEngine((call) async => 1);
    final service = FlutterTtsSpeechService();
    await service.stop();
    expect(calls, isEmpty);
    expect(service.speaking.value, isFalse);
  });

  test('langue indisponible : repli silencieux, rien n\'est lu', () async {
    mockEngine((call) async => call.method == 'isLanguageAvailable' ? false : 1);
    final service = FlutterTtsSpeechService();

    await service.speak('Bonjour', languageTag: 'fr-FR');

    expect(calls.map((c) => c.method), ['isLanguageAvailable']);
    expect(service.speaking.value, isFalse);
  });

  test('moteur absent ou en panne : aucune exception, pas en lecture', () async {
    mockEngine((call) async => throw PlatformException(code: 'TtsError', message: 'pas de moteur'));
    final service = FlutterTtsSpeechService();

    await service.speak('Bonjour', languageTag: 'en-US');
    await service.stop();

    expect(service.speaking.value, isFalse);
  });

  test('aucun plugin enregistré (MissingPluginException) : repli silencieux', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    final service = FlutterTtsSpeechService();

    await service.speak('Bonjour', languageTag: 'fr-FR');

    expect(service.speaking.value, isFalse);
  });

  test('erreur signalée par le moteur pendant la lecture : plus en lecture', () async {
    mockEngine((call) async => call.method == 'isLanguageAvailable' ? true : 1);
    late FlutterTts engine;
    final service = FlutterTtsSpeechService(create: () => engine = FlutterTts());
    await service.speak('Bonjour', languageTag: 'fr-FR');
    expect(service.speaking.value, isTrue);

    await engine.platformCallHandler(const MethodCall('speak.onError', 'panne'));

    expect(service.speaking.value, isFalse);
  });
}
