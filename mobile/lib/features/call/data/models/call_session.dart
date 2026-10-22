// Appel à l'équipe NetBuis (D-25) : réponses de POST /api/calls/sessions/ et du suivi de la session,
// puis lien WhatsApp (POST /api/calls/whatsapp/).
import '../../../../core/network/api_exception.dart';

// ZONE SENSIBLE : le nom de la salle et le jeton Jitsi ne doivent être ni affichés, ni journalisés,
// ni stockés. Aucun numéro de commerçant n'existe dans les appels à l'équipe.

/// États d'une session d'appel, tels que l'API les écrit (`state`).
enum CallState {
  ringing('ringing'),
  answered('answered'),
  ended('ended'),
  missed('missed'),
  declined('declined'),
  unavailable('unavailable'),
  cancelled('cancelled');

  const CallState(this.value);
  final String value;

  /// Vrai quand plus rien ne peut changer.
  bool get isFinal =>
      this != CallState.ringing && this != CallState.answered;

  /// Lève [FormatException] si la valeur n'est pas dans le contrat.
  static CallState parse(Object? value) {
    for (final s in CallState.values) {
      if (s.value == value) return s;
    }
    throw const FormatException('état inconnu');
  }
}

/// De quoi rejoindre la salle Jitsi. Objet à vie courte : il va du dépôt au service Jitsi et
/// n'est jamais gardé dans un état, une liste, un stockage, un message d'erreur ou un journal.
class JitsiAccess {
  const JitsiAccess(
      {required this.domain, required String room, required String jwt})
      : _room = room,
        _jwt = jwt;

  /// Lit `{domain, room, jwt}`. Lève [FormatException] (sans détail) si l'un manque ou est vide.
  factory JitsiAccess.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('réponse inattendue');
    final domain = json['domain'];
    final room = json['room'];
    final jwt = json['jwt'];
    if (domain is! String ||
        room is! String ||
        jwt is! String ||
        domain.isEmpty ||
        room.isEmpty ||
        jwt.isEmpty) {
      throw const FormatException('réponse incomplète');
    }
    return JitsiAccess(domain: domain, room: room, jwt: jwt);
  }

  /// Domaine du serveur Jitsi (sans `https://`).
  final String domain;
  final String _room;
  final String _jwt;

  /// À passer au service Jitsi uniquement.
  String get room => _room;

  /// À passer au service Jitsi uniquement.
  String get jwt => _jwt;

  /// Adresse du serveur pour le SDK.
  String get serverUrl => 'https://$domain';

  /// Jamais la salle ni le jeton : ce texte peut finir dans un message d'erreur ou un journal.
  @override
  String toString() => 'JitsiAccess($domain)';
}

/// Réponse de `POST /api/calls/sessions/`.
class CallStart {
  const CallStart({
    required this.sessionId,
    required this.state,
    required this.ringSeconds,
    this.code,
    this.jitsi,
  });

  /// Lit la réponse. Un appel qui sonne DOIT porter de quoi rejoindre la salle.
  factory CallStart.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('réponse inattendue');
    final id = json['session_id'];
    final ring = json['ring_seconds'];
    final code = json['code'];
    final state = CallState.parse(json['state']);
    if (id is! String || id.isEmpty || ring is! int) {
      throw const FormatException('réponse incomplète');
    }
    final raw = json['jitsi'];
    final jitsi = raw == null ? null : JitsiAccess.fromJson(raw);
    if (state == CallState.ringing && jitsi == null) {
      throw const FormatException('salle manquante');
    }
    return CallStart(
      sessionId: id,
      state: state,
      ringSeconds: ring,
      code: code is String ? code : null,
      jitsi: jitsi,
    );
  }

  final String sessionId;
  final CallState state;

  /// Durée de sonnerie annoncée par le serveur (0 si personne n'est disponible).
  final int ringSeconds;
  final String? code;
  final JitsiAccess? jitsi;

  @override
  String toString() => 'CallStart($state)';
}

/// État d'une session (flux `state` ou `GET /api/calls/sessions/{id}/`).
class CallStatus {
  const CallStatus({required this.sessionId, required this.state, this.reason = ''});

  factory CallStatus.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('réponse inattendue');
    final id = json['session_id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('réponse incomplète');
    }
    final reason = json['end_reason'] ?? json['reason'];
    return CallStatus(
      sessionId: id,
      state: CallState.parse(json['state']),
      reason: reason is String ? reason : '',
    );
  }

  final String sessionId;
  final CallState state;

  /// Motif de fin (`caller_hangup`, `timeout`…), vide si absent.
  final String reason;
}

/// 409 `call_already_active` : une session de cet appelant est encore en cours. [sessionId] est
/// celle du serveur (vide si elle n'a pas été donnée).
class ActiveCallException extends ApiException {
  const ActiveCallException(this.sessionId)
      : super(ApiErrorCode.unknown,
            statusCode: 409, serverCode: 'call_already_active');

  final String sessionId;
}

/// Un lien WhatsApp autorisé par le serveur (`POST /api/calls/whatsapp/`). Le lien
/// `https://wa.me/237…` CONTIENT le numéro du commerçant : objet à vie courte, qui va du dépôt
/// au code natif ; jamais affiché, journalisé, stocké, ni mis dans une erreur.
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
