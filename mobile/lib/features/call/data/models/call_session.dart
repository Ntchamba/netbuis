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

/// Un lien WhatsApp autorisé par le serveur (canal `whatsapp`). Le lien `https://wa.me/237…`
/// CONTIENT le numéro du commerçant : mêmes règles que le numéro. Objet à vie courte, qui va
/// du dépôt au code natif ; jamais affiché, journalisé, stocké, ni mis dans une erreur.
class WhatsappLink {
  const WhatsappLink({required this.callId, required String url}) : _url = url;

  /// Lit `{call_id, wa_url}`. Lève [FormatException] (sans détail) si l'un des deux manque,
  /// ou si le lien n'est pas un lien `https://wa.me/…`.
  factory WhatsappLink.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('réponse inattendue');
    final id = json['call_id'];
    final url = json['wa_url'];
    if (id is! int || url is! String || !isWhatsappUrl(url)) {
      throw const FormatException('réponse incomplète');
    }
    return WhatsappLink(callId: id, url: url);
  }

  /// Seul hôte accepté : on n'ouvre jamais un autre site avec ce canal.
  static bool isWhatsappUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'wa.me' &&
        uri.path.length > 1;
  }

  final int callId;
  final String _url;

  /// À passer au code natif uniquement.
  String get url => _url;

  /// Jamais le lien : ce texte peut finir dans un message d'erreur ou un journal.
  @override
  String toString() => 'WhatsappLink(callId: $callId)';
}
