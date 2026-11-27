// Référentiels (secteurs, catégories de service, types de structure) et catalogue

/// Un élément de référentiel : secteur (sans ses sous-catégories), sous-catégorie,
/// catégorie de service ou type de structure. Immuable.
class ReferentialItem {
  const ReferentialItem({
    required this.id,
    required this.code,
    required this.name,
    this.icon = '',
    this.order = 0,
  });

  final int id;

  /// Code stable (minuscules sans accents) à envoyer au serveur.
  final String code;
  final String name;

  /// Pictogramme (emoji) tel que donné par le serveur ; peut être vide.
  final String icon;
  final int order;

  /// Lève [FormatException] si la réponse n'a pas la forme du contrat.
  factory ReferentialItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final code = json['code'];
    final name = json['name'];
    final icon = json['icon'];
    final order = json['order'];
    if (id is! int ||
        code is! String ||
        code.isEmpty ||
        name is! String ||
        name.isEmpty ||
        (icon != null && icon is! String) ||
        (order != null && order is! int)) {
      throw const FormatException('Élément de référentiel inattendu');
    }
    return ReferentialItem(
      id: id,
      code: code,
      name: name,
      icon: (icon as String?) ?? '',
      order: (order as int?) ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReferentialItem &&
      other.id == id &&
      other.code == code &&
      other.name == name &&
      other.icon == icon &&
      other.order == order;

  @override
  int get hashCode => Object.hash(id, code, name, icon, order);
}

/// Un secteur d'activité avec ses sous-catégories actives.
class Sector {
  const Sector({required this.item, required this.subcategories});

  final ReferentialItem item;
  final List<ReferentialItem> subcategories;

  int get id => item.id;
  String get code => item.code;
  String get name => item.name;
  String get icon => item.icon;
  int get order => item.order;

  factory Sector.fromJson(Map<String, dynamic> json) {
    final subs = json['subcategories'];
    if (subs is! List) throw const FormatException('Secteur inattendu');
    return Sector(
      item: ReferentialItem.fromJson(json),
      subcategories: List.unmodifiable([
        for (final s in subs)
          if (s is Map<String, dynamic>)
            ReferentialItem.fromJson(s)
          else
            throw const FormatException('Sous-catégorie inattendue'),
      ]),
    );
  }
}

/// Un produit proposé par la complétion du catalogue.
class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    this.sector,
    this.subcategory,
  });

  final int id;
  final String name;

  /// Code du secteur, ou null.
  final String? sector;

  /// Code de la sous-catégorie, ou null.
  final String? subcategory;

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final sector = json['sector'];
    final sub = json['subcategory'];
    if (id is! int ||
        name is! String ||
        (sector != null && sector is! String) ||
        (sub != null && sub is! String)) {
      throw const FormatException('Produit inattendu');
    }
    return CatalogProduct(
        id: id, name: name, sector: sector as String?, subcategory: sub as String?);
  }
}
