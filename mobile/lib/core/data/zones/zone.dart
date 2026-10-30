// Zones géographiques (GET /api/zones/)

/// Niveaux de la hiérarchie, dans l'ordre du pays au repère.
enum ZoneLevel {
  pays('pays'),
  region('region'),
  departement('departement'),
  arrondissement('arrondissement'),
  villeVillage('ville_village'),
  quartier('quartier'),
  repere('repere');

  const ZoneLevel(this.value);

  /// Valeur échangée avec le serveur (paramètre `level` et champ `level`).
  final String value;

  /// Lève [FormatException] si le niveau est inconnu.
  static ZoneLevel parse(Object? value) {
    for (final l in ZoneLevel.values) {
      if (l.value == value) return l;
    }
    throw const FormatException('Niveau de zone inconnu');
  }
}

/// Une zone active (pays, région, ville, quartier…). Immuable.
class Zone {
  const Zone({
    required this.id,
    required this.name,
    required this.level,
    this.parent,
    this.officialCode = '',
    this.order = 0,
    this.latitude,
    this.longitude,
  });

  final int id;
  final String name;
  final ZoneLevel level;

  /// Identifiant de la zone parente ; null pour le pays.
  final int? parent;
  final String officialCode;
  final int order;
  final double? latitude;
  final double? longitude;

  /// Lève [FormatException] si la réponse n'a pas la forme du contrat.
  factory Zone.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final parent = json['parent'];
    final order = json['order'];
    final code = json['official_code'];
    final lat = json['latitude'];
    final lng = json['longitude'];
    if (id is! int || name is! String || name.isEmpty) {
      throw const FormatException('Zone inattendue');
    }
    if ((parent != null && parent is! int) ||
        (order != null && order is! int) ||
        (code != null && code is! String) ||
        (lat != null && lat is! num) ||
        (lng != null && lng is! num)) {
      throw const FormatException('Zone inattendue');
    }
    return Zone(
      id: id,
      name: name,
      level: ZoneLevel.parse(json['level']),
      parent: parent as int?,
      officialCode: (code as String?) ?? '',
      order: (order as int?) ?? 0,
      latitude: (lat as num?)?.toDouble(),
      longitude: (lng as num?)?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Zone &&
      other.id == id &&
      other.name == name &&
      other.level == level &&
      other.parent == parent &&
      other.officialCode == officialCode &&
      other.order == order &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode =>
      Object.hash(id, name, level, parent, officialCode, order, latitude, longitude);
}

/// Un maillon du chemin d'une zone (du pays jusqu'à la zone elle-même).
class ZonePathItem {
  const ZonePathItem({required this.id, required this.name, required this.level});

  final int id;
  final String name;
  final ZoneLevel level;

  factory ZonePathItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! int || name is! String) {
      throw const FormatException('Chemin de zone inattendu');
    }
    return ZonePathItem(id: id, name: name, level: ZoneLevel.parse(json['level']));
  }

  @override
  bool operator ==(Object other) =>
      other is ZonePathItem && other.id == id && other.name == name && other.level == level;

  @override
  int get hashCode => Object.hash(id, name, level);
}

/// Une zone avec son chemin (GET /api/zones/{id}/).
class ZoneDetail {
  const ZoneDetail({required this.zone, required this.path});

  final Zone zone;

  /// Du pays jusqu'à la zone incluse.
  final List<ZonePathItem> path;

  factory ZoneDetail.fromJson(Map<String, dynamic> json) {
    final path = json['path'];
    if (path is! List) throw const FormatException('Zone inattendue');
    return ZoneDetail(
      zone: Zone.fromJson(json),
      path: List.unmodifiable([
        for (final item in path)
          if (item is Map<String, dynamic>)
            ZonePathItem.fromJson(item)
          else
            throw const FormatException('Chemin de zone inattendu'),
      ]),
    );
  }
}
