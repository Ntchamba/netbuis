// Compte business du propriétaire (GET/POST /api/business/…) et adresse d'envoi d'un fichier

/// Statut du compte business (`status`), tel que le serveur l'écrit.
enum BusinessStatus {
  pending('en_attente_validation'),
  active('actif'),
  rejected('rejete');

  const BusinessStatus(this.value);

  final String value;

  /// Lève [FormatException] pour un statut inconnu.
  static BusinessStatus parse(Object? value) {
    for (final s in BusinessStatus.values) {
      if (s.value == value) return s;
    }
    throw const FormatException('Statut de compte business inconnu');
  }
}

/// Ce que l'écran Profil montre du compte business du propriétaire : jamais le numéro
/// entier ni la CNI (le serveur ne les renvoie pas), seulement le statut et le motif.
class MyBusiness {
  const MyBusiness({
    required this.status,
    this.name = '',
    this.motifRejet = '',
  });

  final BusinessStatus status;
  final String name;

  /// Raison du rejet donnée par l'équipe ; vide hors du statut `rejete`.
  final String motifRejet;

  /// Lève [FormatException] si la réponse n'a pas la forme du contrat.
  factory MyBusiness.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final motif = json['motif_rejet'];
    return MyBusiness(
      status: BusinessStatus.parse(json['status']),
      name: name is String ? name.trim() : '',
      motifRejet: motif is String ? motif.trim() : '',
    );
  }
}

/// Réponse de `POST /api/uploads/sign/` : où envoyer UN fichier, et la clé à mettre ensuite
/// dans le profil. Sensible : ne jamais journaliser ni afficher.
class UploadTicket {
  const UploadTicket({
    required this.key,
    required this.uploadUrl,
    required this.headers,
    this.expiresIn,
  });

  /// Clé de stockage, à envoyer dans `photo`, `representant_photo`, `cni_photo`, `diplome_photo`.
  final String key;

  /// Chemin du serveur (`/api/uploads/local/<jeton>/`) ou adresse complète.
  final String uploadUrl;

  /// En-têtes à envoyer **tels quels** avec le PUT.
  final Map<String, String> headers;
  final int? expiresIn;

  /// Lève [FormatException] si la réponse n'a pas la forme du contrat (méthode PUT).
  factory UploadTicket.fromJson(Map<String, dynamic> json) {
    final key = json['key'];
    final url = json['upload_url'];
    final method = json['method'];
    final headers = json['headers'];
    final expires = json['expires_in'];
    if (key is! String ||
        key.isEmpty ||
        url is! String ||
        url.isEmpty ||
        (method != null && method != 'PUT') ||
        (headers != null && headers is! Map)) {
      throw const FormatException('Adresse d\'envoi inattendue');
    }
    return UploadTicket(
      key: key,
      uploadUrl: url,
      headers: {
        if (headers is Map)
          for (final e in headers.entries)
            if (e.value is String) '${e.key}': e.value as String,
      },
      expiresIn: expires is int ? expires : null,
    );
  }
}
