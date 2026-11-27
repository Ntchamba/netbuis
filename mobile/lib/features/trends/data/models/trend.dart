// Tendances près de chez soi (GET /api/trends/) : produits et commerces les plus demandés
// Le contrat ne contient aucun numéro ni compteur ; les champs inconnus sont ignorés.

/// Un produit très demandé. [name] est le texte à lancer tel quel comme recherche.
class TrendProduct {
  const TrendProduct({required this.id, required this.name, required this.rank});

  final int id;
  final String name;
  final int rank;

  /// Lève [FormatException] si l'élément n'a pas la forme du contrat.
  factory TrendProduct.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final rank = json['rank'];
    if (id is! int || name is! String || name.trim().isEmpty || rank is! int) {
      throw const FormatException('Produit de tendance inattendu');
    }
    return TrendProduct(id: id, name: name.trim(), rank: rank);
  }

  @override
  bool operator ==(Object other) =>
      other is TrendProduct && other.id == id && other.name == name && other.rank == rank;

  @override
  int get hashCode => Object.hash(id, name, rank);
}

/// Un commerce très contacté : nom et zone seulement. [id] ouvre la fiche publique.
class TrendBusiness {
  const TrendBusiness({
    required this.id,
    required this.name,
    required this.zoneId,
    required this.zoneName,
    required this.rank,
  });

  final int id;
  final String name;
  final int zoneId;
  final String zoneName;
  final int rank;

  /// Lève [FormatException] si l'élément n'a pas la forme du contrat.
  factory TrendBusiness.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final rank = json['rank'];
    final zone = json['zone'];
    if (id is! int ||
        name is! String ||
        name.trim().isEmpty ||
        rank is! int ||
        zone is! Map<String, dynamic>) {
      throw const FormatException('Commerce de tendance inattendu');
    }
    final zoneId = zone['id'];
    final zoneName = zone['name'];
    if (zoneId is! int || zoneName is! String) {
      throw const FormatException('Commerce de tendance inattendu');
    }
    return TrendBusiness(
        id: id, name: name.trim(), zoneId: zoneId, zoneName: zoneName, rank: rank);
  }

  @override
  bool operator ==(Object other) =>
      other is TrendBusiness &&
      other.id == id &&
      other.name == name &&
      other.zoneId == zoneId &&
      other.zoneName == zoneName &&
      other.rank == rank;

  @override
  int get hashCode => Object.hash(id, name, zoneId, zoneName, rank);
}

/// Réponse de GET /api/trends/ pour une zone. Listes triées par rang.
class Trends {
  const Trends({
    this.zoneId,
    this.zoneName,
    this.computedAt,
    this.periodDays,
    this.products = const [],
    this.businesses = const [],
  });

  /// Rien à montrer (aucune zone, erreur, ou pas encore de calcul).
  static const Trends empty = Trends();

  final int? zoneId;
  final String? zoneName;
  final DateTime? computedAt;
  final int? periodDays;
  final List<TrendProduct> products;
  final List<TrendBusiness> businesses;

  bool get isEmpty => products.isEmpty && businesses.isEmpty;

  /// Lève [FormatException] si la réponse n'a pas la forme du contrat. Un élément de liste
  /// mal formé est écarté (le reste de la bande reste utile).
  factory Trends.fromJson(Map<String, dynamic> json) {
    final zone = json['zone'];
    final computed = json['computed_at'];
    final period = json['period_days'];
    final products = json['products'];
    final businesses = json['businesses'];
    if ((zone != null && zone is! Map<String, dynamic>) ||
        (computed != null && computed is! String) ||
        (period != null && period is! int) ||
        products is! List ||
        businesses is! List) {
      throw const FormatException('Tendances inattendues');
    }
    int? zoneId;
    String? zoneName;
    if (zone is Map<String, dynamic>) {
      final id = zone['id'];
      final name = zone['name'];
      if (id is! int || name is! String) {
        throw const FormatException('Tendances inattendues');
      }
      zoneId = id;
      zoneName = name;
    }
    final parsedProducts = <TrendProduct>[];
    for (final item in products) {
      if (item is! Map<String, dynamic>) continue;
      try {
        parsedProducts.add(TrendProduct.fromJson(item));
      } on FormatException {
        continue;
      }
    }
    final parsedBusinesses = <TrendBusiness>[];
    for (final item in businesses) {
      if (item is! Map<String, dynamic>) continue;
      try {
        parsedBusinesses.add(TrendBusiness.fromJson(item));
      } on FormatException {
        continue;
      }
    }
    parsedProducts.sort((a, b) => a.rank.compareTo(b.rank));
    parsedBusinesses.sort((a, b) => a.rank.compareTo(b.rank));
    return Trends(
      zoneId: zoneId,
      zoneName: zoneName,
      computedAt: computed == null ? null : DateTime.tryParse(computed as String),
      periodDays: period as int?,
      products: List.unmodifiable(parsedProducts),
      businesses: List.unmodifiable(parsedBusinesses),
    );
  }
}
