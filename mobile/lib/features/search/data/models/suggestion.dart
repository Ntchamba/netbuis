// Une suggestion pendant la frappe (GET /api/search/suggestions/)

/// Nature d'une suggestion : `produit` (catalogue) ou `recherche` (terme souvent cherché).
enum SuggestionType {
  produit('produit'),
  recherche('recherche');

  const SuggestionType(this.value);
  final String value;

  /// Lève [FormatException] si la valeur est inconnue.
  static SuggestionType parse(Object? value) {
    for (final t in SuggestionType.values) {
      if (t.value == value) return t;
    }
    throw const FormatException('Type de suggestion inconnu');
  }
}

class Suggestion {
  const Suggestion({required this.text, required this.type});

  final String text;
  final SuggestionType type;

  /// Lève [FormatException] si la réponse n'a pas la forme du contrat.
  factory Suggestion.fromJson(Map<String, dynamic> json) {
    final text = json['text'];
    if (text is! String || text.isEmpty) {
      throw const FormatException('Suggestion inattendue');
    }
    return Suggestion(text: text, type: SuggestionType.parse(json['type']));
  }

  @override
  bool operator ==(Object other) =>
      other is Suggestion && other.text == text && other.type == type;

  @override
  int get hashCode => Object.hash(text, type);
}

/// Nombre maximal de suggestions affichées.
const int kMaxSuggestions = 8;

/// Nombre minimal de caractères avant de demander des suggestions.
const int kMinSuggestionChars = 2;
