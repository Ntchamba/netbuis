// Partage Android : ouvre la feuille de partage du téléphone avec un texte
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ouvre la feuille de partage du système avec [text].
abstract class ShareService {
  /// Lève une [PlatformException] si la feuille ne peut pas s'ouvrir.
  Future<void> shareText(String text);
}

/// Canal minimal vers `MainActivity.kt` (intention ACTION_SEND), sans dépendance de plus.
class PlatformShareService implements ShareService {
  const PlatformShareService({this.isWeb = kIsWeb});

  /// Vrai dans la version web (PWA) : pas de feuille de partage native.
  final bool isWeb;

  static const MethodChannel channel = MethodChannel('cm.netbuis/share');

  @override
  Future<void> shareText(String text) async {
    if (isWeb) throw PlatformException(code: 'web_unsupported');
    await channel.invokeMethod<void>('shareText', {'text': text});
  }
}

/// Remplaçable dans les tests.
final shareServiceProvider = Provider<ShareService>((ref) => const PlatformShareService());
