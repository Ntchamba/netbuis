// Compte business du propriétaire (GET/POST/PATCH /api/business/…) et adresse d'envoi d'un fichier
import 'business_draft.dart' show BusinessAccountType;

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

/// Ce que l'écran Profil montre du compte business du propriétaire, et ce qu'il faut pour le
/// modifier : jamais le numéro entier ni la CNI (le serveur ne les renvoie pas), seulement le
/// statut, le motif et, pour les photos, le fait qu'elles existent (la clé de stockage n'est
/// pas gardée).
class MyBusiness {
  const MyBusiness({
    required this.status,
    this.name = '',
    this.motifRejet = '',
    this.typeCompte,
    this.zoneId,
    this.repere = '',
    this.description = '',
    this.descriptionActivite = '',
    this.representantNom = '',
    this.hasPhoto = false,
    this.hasRepresentantPhoto = false,
    this.hasCni = false,
    this.hasDiplome = false,
    this.suggestSubscription = false,
  });

  final BusinessStatus status;
  final String name;

  /// Raison du rejet donnée par l'équipe ; vide hors du statut `rejete`.
  final String motifRejet;

  /// Type de compte (non modifiable depuis « Modifier ma boutique ») ; null si la réponse
  /// ne le donne pas.
  final BusinessAccountType? typeCompte;

  /// Identifiant de la zone (ville/village ou quartier) enregistrée.
  final int? zoneId;
  final String repere;
  final String description;
  final String descriptionActivite;
  final String representantNom;
  final bool hasPhoto;
  final bool hasRepresentantPhoto;
  final bool hasCni;
  final bool hasDiplome;

  /// `suggest_subscription` : le serveur juge que le compte reçoit beaucoup d'appels. Faux si le
  /// champ est absent. L'encart du Profil ne s'en sert que pour un compte actif.
  final bool suggestSubscription;

  /// Lève [FormatException] si la réponse n'a pas la forme du contrat.
  factory MyBusiness.fromJson(Map<String, dynamic> json) {
    String text(String key) {
      final v = json[key];
      return v is String ? v.trim() : '';
    }

    bool filled(String key) {
      final v = json[key];
      return v is String && v.isNotEmpty;
    }

    BusinessAccountType? type;
    for (final t in BusinessAccountType.values) {
      if (t.value == json['type_compte']) type = t;
    }
    final zone = json['zone'];
    return MyBusiness(
      status: BusinessStatus.parse(json['status']),
      name: text('name'),
      motifRejet: text('motif_rejet'),
      typeCompte: type,
      zoneId: zone is int ? zone : null,
      repere: text('repere'),
      description: text('description'),
      descriptionActivite: text('description_activite'),
      representantNom: text('representant_nom'),
      hasPhoto: filled('photo'),
      hasRepresentantPhoto: filled('representant_photo'),
      hasCni: json['has_cni'] == true,
      hasDiplome: filled('diplome_photo'),
      suggestSubscription: json['suggest_subscription'] == true,
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
