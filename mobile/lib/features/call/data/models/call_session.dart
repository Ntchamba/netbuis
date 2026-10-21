// Réponse de POST /api/calls/initiate/ (canal « call ») et lignes proposées.
// ZONE SENSIBLE : le numéro du commerçant ne doit être ni affiché, ni journalisé, ni stocké.

/// Les deux lignes proposées (D-22 : redemandée à chaque appel). La valeur est celle de l'API.
enum CallLine {
  orange('orange'),
  mtn('mtn');

  const CallLine(this.value);
  final String value;

  CallLine get other => this == orange ? mtn : orange;
}

/// Un appel autorisé par le serveur. Objet à vie courte : il va du dépôt au code natif
/// et n'est jamais gardé dans un état, une liste ou un stockage.
class CallSession {
  const CallSession({required this.callId, required String phone}) : _phone = phone;

  /// Lit `{call_id, phone}`. Lève [FormatException] si l'un des deux manque ou est vide.
  factory CallSession.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('réponse inattendue');
    final id = json['call_id'];
    final phone = json['phone'];
    if (id is! int || phone is! String || phone.isEmpty) {
      throw const FormatException('réponse incomplète');
    }
    return CallSession(callId: id, phone: phone);
  }

  final int callId;
  final String _phone;

  /// À passer au code natif uniquement.
  String get phone => _phone;

  /// Jamais le numéro : ce texte peut finir dans un message d'erreur ou un journal.
  @override
  String toString() => 'CallSession(callId: $callId)';
}
