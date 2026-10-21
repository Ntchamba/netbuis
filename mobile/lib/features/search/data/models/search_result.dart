// Un résultat de recherche et une page de résultats.
// Aucun numéro de téléphone : il ne sort que de POST /api/calls/initiate/.

class ResultZone {
  const ResultZone({required this.id, required this.name});

  final int id;
  final String name;

  @override
  bool operator ==(Object other) => other is ResultZone && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

class SearchResult {
  const SearchResult({
    required this.id,
    required this.name,
    required this.kind,
    this.secteur = '',
    this.secteurCode,
    this.zone,
    this.repere = '',
    this.descriptionActivite = '',
    this.photo,
    this.prixIndicatif,
    this.verifie = false,
    this.whatsappAvailable = true,
  });

  /// Identifiant du compte business (fiche publique).
  final int id;
  final String name;

  /// « produit » ou « service ».
  final String kind;
  final String secteur;
  final String? secteurCode;
  final ResultZone? zone;
  final String repere;

  /// Sous-titre de la carte.
  final String descriptionActivite;

  /// Adresse de la photo, ou null.
  final String? photo;

  /// Plus petit prix (FCFA) ; null = sur demande.
  final int? prixIndicatif;

  /// Badge « ✓ Identité vérifiée ».
  final bool verifie;

  /// Faux : le bouton WhatsApp est grisé (« Non disponible »). Absent de la réponse = vrai ;
  /// dans ce cas le serveur refuse lui-même avec CHANNEL_UNAVAILABLE si WhatsApp est coupé.
  final bool whatsappAvailable;

  /// Lève [FormatException] si la réponse n'a pas la forme du contrat.
  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final kind = json['kind'];
    final zone = json['zone'];
    final price = json['prix_indicatif'];
    final photo = json['photo'];
    final code = json['secteur_code'];
    if (id is! int || name is! String || kind is! String) {
      throw const FormatException('Résultat inattendu');
    }
    if ((zone != null && zone is! Map) ||
        (price != null && price is! int) ||
        (photo != null && photo is! String) ||
        (code != null && code is! String)) {
      throw const FormatException('Résultat inattendu');
    }
    ResultZone? parsedZone;
    if (zone is Map) {
      final zid = zone['id'];
      final zname = zone['name'];
      if (zid is! int || zname is! String) throw const FormatException('Résultat inattendu');
      parsedZone = ResultZone(id: zid, name: zname);
    }
    final secteur = json['secteur'];
    final repere = json['repere'];
    final desc = json['description_activite'];
    return SearchResult(
      id: id,
      name: name,
      kind: kind,
      secteur: secteur is String ? secteur : '',
      secteurCode: code as String?,
      zone: parsedZone,
      repere: repere is String ? repere : '',
      descriptionActivite: desc is String ? desc : '',
      photo: photo as String?,
      prixIndicatif: price as int?,
      verifie: json['verifie'] == true,
      whatsappAvailable: json['whatsapp_available'] != false,
    );
  }
}

/// Une page de résultats ({count, next, previous, results}).
class SearchPage {
  const SearchPage({
    required this.count,
    required this.results,
    required this.hasNext,
    this.cleanedQuery,
  });

  final int count;
  final List<SearchResult> results;

  /// Vrai quand le serveur annonce une page suivante (`next` non nul).
  final bool hasNext;

  /// Pour la recherche vocale : le terme cherché après nettoyage (`q`).
  final String? cleanedQuery;

  /// Lève [FormatException] si la réponse n'a pas la forme du contrat.
  factory SearchPage.fromJson(Object? data) {
    if (data is! Map<String, dynamic>) throw const FormatException('Page inattendue');
    final results = data['results'];
    final count = data['count'];
    if (results is! List || count is! int) throw const FormatException('Page inattendue');
    final q = data['q'];
    return SearchPage(
      count: count,
      hasNext: data['next'] != null,
      cleanedQuery: q is String ? q : null,
      results: List.unmodifiable([
        for (final item in results)
          if (item is Map<String, dynamic>)
            SearchResult.fromJson(item)
          else
            throw const FormatException('Résultat inattendu'),
      ]),
    );
  }
}
