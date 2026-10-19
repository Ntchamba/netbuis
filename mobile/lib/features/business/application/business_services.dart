import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/photo_service.dart';
import '../data/speech_service.dart';

/// Synthèse vocale du téléphone (remplaçable dans les tests).
final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = FlutterTtsSpeechService();
  ref.onDispose(service.stop);
  return service;
});

/// Appareil photo et galerie (remplaçable dans les tests).
final photoPickerProvider = Provider<PhotoPickerService>((ref) => ImagePickerPhotoService());
