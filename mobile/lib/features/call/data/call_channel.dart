// Pont vers le code Android (CallChannel.kt) : permissions, lignes (SIM) et appel.
// ZONE SENSIBLE : [CallChannel.placeCall], [CallChannel.dial] et [CallChannel.openWhatsapp] (lien
// wa.me qui contient le numéro) reçoivent le numéro du
// commerçant. Rien ici ne l'affiche, ne le journalise, ne le garde, ni ne le met dans une erreur.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Une ligne (compte téléphonique) du téléphone, avec les noms donnés par le système.
class SimAccount {
  const SimAccount({required this.id, required this.label, this.carrier = ''});

  /// Identifiant opaque rendu par le code natif et renvoyé tel quel à [CallChannel.placeCall].
  final String id;

  /// Nom de la SIM affiché par le système (peut avoir été renommé par l'utilisateur).
  final String label;

  /// Nom de l'opérateur lu sur la SIM (vide si illisible, par exemple certaines eSIM).
  final String carrier;

  /// Nom à montrer à l'utilisateur dans le repli « noms de SIM ».
  String get displayName {
    final l = label.trim();
    final c = carrier.trim();
    if (l.isEmpty) return c;
    if (c.isEmpty || l.toLowerCase() == c.toLowerCase()) return l;
    return '$l ($c)';
  }

  @override
  String toString() => 'SimAccount($label)';
}

/// État des autorisations : [granted] = CALL_PHONE et READ_PHONE_STATE accordées ;
/// [asked] = la demande Android a déjà été faite une fois (on ne la refait pas).
class CallPermissions {
  const CallPermissions({required this.granted, required this.asked});
  final bool granted;
  final bool asked;
}

/// Résultat de [CallChannel.placeCall].
enum PlaceCallResult { placed, permissionDenied, accountMissing, failed }

/// Résultat de [CallChannel.openWhatsapp].
enum WhatsappOpenResult { opened, notInstalled, failed }

/// Le code natif a échoué ou n'existe pas (autre plateforme). Aucun détail : il pourrait
/// contenir le numéro.
class CallChannelException implements Exception {
  const CallChannelException();

  @override
  String toString() => 'CallChannelException';
}

abstract class CallChannel {
  Future<CallPermissions> permissions();

  /// Affiche la demande Android (CALL_PHONE + READ_PHONE_STATE) ; vrai si tout est accordé.
  Future<bool> requestPermissions();

  /// Lignes capables d'appeler ; vide si illisibles ou sans SIM.
  Future<List<SimAccount>> listSims();

  /// `TelecomManager.placeCall` avec la ligne [accountId] (ou la ligne par défaut si null).
  Future<PlaceCallResult> placeCall({required String phone, String? accountId});

  /// Repli : ouvre le composeur du téléphone (ACTION_DIAL) ; le numéro y est visible.
  /// Faux si aucune application ne peut l'ouvrir.
  Future<bool> dial(String phone);

  /// Ouvre le lien WhatsApp [url] (`https://wa.me/…`, qui CONTIENT le numéro) directement dans
  /// l'application WhatsApp. [WhatsappOpenResult.notInstalled] si WhatsApp est absent du téléphone.
  Future<WhatsappOpenResult> openWhatsapp(String url);
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
  Future<CallPermissions> permissions() async {
    final r = await _invoke<Map<Object?, Object?>>('permissions');
    if (r == null) throw const CallChannelException();
    return CallPermissions(granted: r['granted'] == true, asked: r['asked'] == true);
  }

  @override
  Future<bool> requestPermissions() async =>
      (await _invoke<bool>('requestPermissions')) == true;

  @override
  Future<List<SimAccount>> listSims() async {
    final r = await _invoke<List<Object?>>('listSims');
    if (r == null) return const [];
    return [
      for (final e in r)
        if (e is Map && e['id'] is String)
          SimAccount(
            id: e['id'] as String,
            label: e['label'] is String ? e['label'] as String : '',
            carrier: e['carrier'] is String ? e['carrier'] as String : '',
          ),
    ];
  }

  @override
  Future<PlaceCallResult> placeCall({required String phone, String? accountId}) async {
    final r = await _invoke<String>('placeCall', {'phone': phone, 'accountId': accountId});
    switch (r) {
      case 'placed':
        return PlaceCallResult.placed;
      case 'no_permission':
        return PlaceCallResult.permissionDenied;
      case 'no_account':
        return PlaceCallResult.accountMissing;
      default:
        return PlaceCallResult.failed;
    }
  }

  @override
  Future<bool> dial(String phone) async => (await _invoke<bool>('dial', {'phone': phone})) == true;

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
}

/// Remplaçable dans les tests par un faux canal.
final callChannelProvider = Provider<CallChannel>((ref) => const PlatformCallChannel());
