// Ce que la personne cherche : texte, ville/zone, secteur

class SearchQuery {
  const SearchQuery({this.q = '', this.zone, this.sector});

  /// Texte cherché ; vide = les commerces de la zone.
  final String q;

  /// Identifiant de la zone (ville, quartier…).
  final int? zone;

  /// Code stable du secteur.
  final String? sector;

  SearchQuery copyWith({
    String? q,
    int? zone,
    bool clearZone = false,
    String? sector,
    bool clearSector = false,
  }) =>
      SearchQuery(
        q: q ?? this.q,
        zone: clearZone ? null : (zone ?? this.zone),
        sector: clearSector ? null : (sector ?? this.sector),
      );

  /// Paramètres de GET /api/search/ (sans les paramètres vides).
  Map<String, Object> toParams(int page) => {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (zone != null) 'zone': zone!,
        if (sector != null && sector!.isNotEmpty) 'sector': sector!,
        'page': page,
      };

  @override
  bool operator ==(Object other) =>
      other is SearchQuery && other.q == q && other.zone == zone && other.sector == sector;

  @override
  int get hashCode => Object.hash(q, zone, sector);
}
