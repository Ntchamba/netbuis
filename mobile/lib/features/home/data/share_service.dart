// Partage Android : ouvre la feuille de partage du téléphone avec un texte
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ouvre la feuille de partage du système avec [text].
abstract class ShareService {
  /// Lève une [PlatformException] si la feuille ne peut pas s'ouvrir.
  Future<void> shareText(String text);
}

/// Canal minimal vers `MainActivity.kt` (intention ACTION_SEND), sans dépendance de plus.
class PlatformShareService implements ShareService {
  const PlatformShareService();

  static const MethodChannel channel = MethodChannel('cm.netbuis/share');

  @override
  Future<void> shareText(String text) => channel.invokeMethod<void>('shareText', {'text': text});
}

/// Remplaçable dans les tests.
final shareServiceProvider = Provider<ShareService>((ref) => const PlatformShareService());
