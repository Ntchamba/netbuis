// Profil de la personne connectée (GET /api/me/)
/// Les champs utiles de l'écran Profil. Le numéro complet n'existe jamais ici :
/// seul [phoneMasked], tel que le serveur le donne, est affiché.
class Me {
  const Me({
    required this.id,
    required this.name,
    required this.phoneMasked,
    this.language = 'fr',
    this.hasBusiness = false,
    this.freeCallAvailable,
    this.creditsBalance,
  });

  final int id;

  /// Nom saisi par la personne ; vide si elle ne l'a pas donné.
  final String name;
  final String phoneMasked;
  final String language;
  final bool hasBusiness;

  /// Null tant que les crédits sont désactivés côté serveur.
  final int? freeCallAvailable;
  final int? creditsBalance;

  bool get hasName => name.trim().isNotEmpty;

  /// Lève [FormatException] si la réponse n'a pas la forme du contrat.
  factory Me.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final phone = json['phone_masked'];
    if (id is! int || phone is! String || phone.isEmpty) {
      throw const FormatException('Réponse /me/ inattendue');
    }
    final name = json['name'];
    final language = json['language'];
    final free = json['free_call_available'];
    final credits = json['credits_balance'];
    return Me(
      id: id,
      name: name is String ? name.trim() : '',
      phoneMasked: phone,
      language: language is String && language.isNotEmpty ? language : 'fr',
      hasBusiness: json['has_business'] == true,
      freeCallAvailable: free is int ? free : null,
      creditsBalance: credits is int ? credits : null,
    );
  }

  Me copyWith({String? name, bool? hasBusiness}) => Me(
        id: id,
        name: name ?? this.name,
        phoneMasked: phoneMasked,
        language: language,
        hasBusiness: hasBusiness ?? this.hasBusiness,
        freeCallAvailable: freeCallAvailable,
        creditsBalance: creditsBalance,
      );
}

/// Initiales de l'avatar : première lettre de chacun des deux premiers mots,
/// en majuscules. Vide si le nom n'a aucune lettre (l'écran montre alors une icône).
String initialsOf(String name) {
  final letter = RegExp(r'^\p{L}', unicode: true);
  final letters = <String>[];
  for (final word in name.trim().split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    final first = String.fromCharCode(word.runes.first);
    if (letter.hasMatch(first)) letters.add(first.toUpperCase());
    if (letters.length == 2) break;
  }
  return letters.join();
}

/// Nom à envoyer : espaces retirés aux extrémités ; vide = rien à envoyer (null).
String? cleanName(String raw) {
  final value = raw.trim();
  return value.isEmpty ? null : value;
}

/// Longueur maximale d'un nom (contrat de l'API).
const int maxNameLength = 120;
