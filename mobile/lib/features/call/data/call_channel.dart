// Pont vers le code Android (AppChannel.kt) : micro, WhatsApp et composeur du support.
// Depuis D-25 il n'y a plus d'appel téléphonique direct : ni lignes (SIM), ni TelecomManager, ni
// permissions « Téléphone ». Le nom du canal (`cm.netbuis/call`) et de cette classe sont gardés
// pour les écrans d'aide et d'abonnement qui s'en servent.
// ZONE SENSIBLE : [CallChannel.openWhatsapp] reçoit le lien wa.me, qui CONTIENT le numéro du
// commerçant. Rien ici ne l'affiche, ne le journalise, ne le garde, ni ne le met dans une erreur.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// État de l'autorisation du micro : [granted] = accordée ;
/// [asked] = la demande Android a déjà été faite une fois.
class MicPermission {
  const MicPermission({required this.granted, required this.asked});
  final bool granted;
  final bool asked;
}

/// Résultat de [CallChannel.openWhatsapp].
enum WhatsappOpenResult { opened, notInstalled, failed }

/// Le code natif a échoué ou n'existe pas (autre plateforme). Aucun détail : il pourrait
/// contenir le lien WhatsApp.
class CallChannelException implements Exception {
  const CallChannelException();

  @override
  String toString() => 'CallChannelException';
}

abstract class CallChannel {
  /// Autorisation du micro (RECORD_AUDIO).
  Future<MicPermission> microphone();

  /// Affiche la demande Android du micro ; vrai si elle est accordée.
  Future<bool> requestMicrophone();

  /// Ouvre le lien WhatsApp [url] (`https://wa.me/…`, qui CONTIENT le numéro) directement dans
  /// l'application WhatsApp. [WhatsappOpenResult.notInstalled] si WhatsApp est absent du téléphone.
  Future<WhatsappOpenResult> openWhatsapp(String url);

  /// Ouvre le composeur du téléphone sur le numéro du SUPPORT NetBuis (écran d'aide).
  /// Faux si aucune application ne peut l'ouvrir.
  Future<bool> dial(String phone);
}

class PlatformCallChannel implements CallChannel {
  const PlatformCallChannel();

  static const MethodChannel channel = MethodChannel('cm.netbuis/call');

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await channel.invokeMethod<T>(method, args);
    } on PlatformException {
      throw const CallChannelException();
    } on MissingPluginException {
      throw const CallChannelException();
    }
  }

  @override
  Future<MicPermission> microphone() async {
    final r = await _invoke<Map<Object?, Object?>>('microphone');
    if (r == null) throw const CallChannelException();
    return MicPermission(granted: r['granted'] == true, asked: r['asked'] == true);
  }

  @override
  Future<bool> requestMicrophone() async =>
      (await _invoke<bool>('requestMicrophone')) == true;

  @override
  Future<WhatsappOpenResult> openWhatsapp(String url) async {
    final r = await _invoke<String>('openWhatsapp', {'url': url});
    switch (r) {
      case 'opened':
        return WhatsappOpenResult.opened;
      case 'not_installed':
        return WhatsappOpenResult.notInstalled;
      default:
        return WhatsappOpenResult.failed;
    }
  }

  @override
  Future<bool> dial(String phone) async => (await _invoke<bool>('dial', {'phone': phone})) == true;
}

/// Remplaçable dans les tests par un faux canal.
final callChannelProvider = Provider<CallChannel>((ref) => const PlatformCallChannel());
