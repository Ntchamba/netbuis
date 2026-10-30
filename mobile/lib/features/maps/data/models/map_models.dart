// Modèles de la carte par zones (GET /api/map/cities/ et /api/map/cities/{id}/areas/).
// Aucun numéro de téléphone ici : l'API n'en renvoie pas.

/// Région ou département de la hiérarchie supérieure.
class MapNode {
  const MapNode({required this.id, required this.name, required this.explorable});

  final int id;
  final String name;
  final bool explorable;

  factory MapNode.fromJson(Object? data) {
    if (data is! Map<String, dynamic>) throw const FormatException('Zone inattendue');
    final id = data['id'];
    final name = data['name'];
    final explorable = data['explorable'];
    if (id is! int || name is! String || explorable is! bool) {
      throw const FormatException('Zone inattendue');
    }
    return MapNode(id: id, name: name, explorable: explorable);
  }
}

/// Une région et ses départements (marqués « explorables » côté serveur).
class MapRegion extends MapNode {
  const MapRegion({
    required super.id,
    required super.name,
    required super.explorable,
    this.departements = const [],
  });

  final List<MapNode> departements;

  factory MapRegion.fromJson(Object? data) {
    final node = MapNode.fromJson(data);
    final deps = (data as Map<String, dynamic>)['departements'];
    if (deps is! List) throw const FormatException('Région inattendue');
    return MapRegion(
      id: node.id,
      name: node.name,
      explorable: node.explorable,
      departements: List.unmodifiable([for (final d in deps) MapNode.fromJson(d)]),
    );
  }
}

/// Une ville ou un village avec au moins un commerce actif.
class MapCity {
  const MapCity({
    required this.id,
    required this.name,
    required this.businessesCount,
    this.latitude,
    this.longitude,
    this.region,
    this.departement,
  });

  final int id;
  final String name;

  /// Commerces actifs (ville + quartiers).
  final int businessesCount;
  final double? latitude;
  final double? longitude;
  final MapNode? region;
  final MapNode? departement;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory MapCity.fromJson(Object? data) {
    if (data is! Map<String, dynamic>) throw const FormatException('Ville inattendue');
    final id = data['id'];
    final name = data['name'];
    final count = data['businesses_count'];
    final lat = data['latitude'];
    final lng = data['longitude'];
    if (id is! int || name is! String || count is! int) {
      throw const FormatException('Ville inattendue');
    }
    if ((lat != null && lat is! num) || (lng != null && lng is! num)) {
      throw const FormatException('Ville inattendue');
    }
    final region = data['region'];
    final departement = data['departement'];
    return MapCity(
      id: id,
      name: name,
      businessesCount: count,
      latitude: (lat as num?)?.toDouble(),
      longitude: (lng as num?)?.toDouble(),
      region: region == null ? null : MapNode.fromJson(region),
      departement: departement == null ? null : MapNode.fromJson(departement),
    );
  }
}

/// Réponse de `GET /api/map/cities/`.
class MapCities {
  const MapCities({required this.cities, required this.regions});

  /// Seulement les villes ayant au moins un commerce : une ville à 0 est écartée ici
  /// même si le serveur en envoyait une (la règle ne dépend pas d'un seul côté).
  final List<MapCity> cities;
  final List<MapRegion> regions;

  factory MapCities.fromJson(Object? data) {
    if (data is! Map<String, dynamic>) throw const FormatException('Carte inattendue');
    final cities = data['cities'];
    final regions = data['regions'];
    if (cities is! List || regions is! List) throw const FormatException('Carte inattendue');
    return MapCities(
      cities: List.unmodifiable([
        for (final c in cities) MapCity.fromJson(c),
      ].where((c) => c.businessesCount > 0)),
      regions: List.unmodifiable([for (final r in regions) MapRegion.fromJson(r)]),
    );
  }
}

/// Un quartier avec ses compteurs.
class MapArea {
  const MapArea({
    required this.id,
    required this.name,
    required this.businessesCount,
    required this.productsCount,
  });

  final int id;
  final String name;
  final int businessesCount;
  final int productsCount;

  factory MapArea.fromJson(Object? data) {
    if (data is! Map<String, dynamic>) throw const FormatException('Quartier inattendu');
    final id = data['id'];
    final name = data['name'];
    final b = data['businesses_count'];
    final p = data['products_count'];
    if (id is! int || name is! String || b is! int || p is! int) {
      throw const FormatException('Quartier inattendu');
    }
    return MapArea(id: id, name: name, businessesCount: b, productsCount: p);
  }
}

/// Réponse de `GET /api/map/cities/{id}/areas/`.
class MapAreas {
  const MapAreas({
    required this.cityId,
    required this.cityName,
    required this.areas,
    required this.businessesWithoutArea,
  });

  final int cityId;
  final String cityName;
  final List<MapArea> areas;

  /// Commerces rattachés à la ville elle-même, sans quartier.
  final int businessesWithoutArea;

  factory MapAreas.fromJson(Object? data) {
    if (data is! Map<String, dynamic>) throw const FormatException('Quartiers inattendus');
    final city = data['city'];
    final areas = data['areas'];
    final without = data['businesses_without_area'];
    if (city is! Map<String, dynamic> || areas is! List || without is! int) {
      throw const FormatException('Quartiers inattendus');
    }
    final cityId = city['id'];
    final cityName = city['name'];
    if (cityId is! int || cityName is! String) {
      throw const FormatException('Quartiers inattendus');
    }
    return MapAreas(
      cityId: cityId,
      cityName: cityName,
      areas: List.unmodifiable([for (final a in areas) MapArea.fromJson(a)]),
      businessesWithoutArea: without,
    );
  }
}
