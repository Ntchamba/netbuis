// Positions indicatives sur la « carte » (aucune carte tierce, aucune tuile).
// Coordonnées de la ville si toutes les villes en ont (au moins deux points distincts),
// sinon placement schématique en grille, comme la maquette.
import '../data/models/map_models.dart';

/// Position relative (0 à 1) d'un repère dans le cadre.
class MapSpot {
  const MapSpot(this.x, this.y);

  final double x;
  final double y;
}

const double _minX = 0.2, _maxX = 0.8, _minY = 0.22, _maxY = 0.8;

/// Placement en grille : [count] repères, lignes remplies de gauche à droite.
List<MapSpot> gridSpots(int count) {
  if (count <= 0) return const [];
  var cols = 1;
  while (cols * cols < count) {
    cols++;
  }
  final rows = (count + cols - 1) ~/ cols;
  return [
    for (var i = 0; i < count; i++)
      MapSpot(
        _minX + (_maxX - _minX) * ((i % cols) + 0.5) / cols,
        _minY + (_maxY - _minY) * ((i ~/ cols) + 0.5) / rows,
      ),
  ];
}

/// Vrai quand les villes peuvent être placées par leurs coordonnées.
bool usesCoordinates(List<MapCity> cities) {
  if (cities.length < 2 || !cities.every((c) => c.hasCoordinates)) return false;
  final first = cities.first;
  return cities.any((c) => c.latitude != first.latitude || c.longitude != first.longitude);
}

/// Une position par ville, dans le même ordre que [cities].
List<MapSpot> citySpots(List<MapCity> cities) {
  if (!usesCoordinates(cities)) return gridSpots(cities.length);
  final lats = cities.map((c) => c.latitude!);
  final lngs = cities.map((c) => c.longitude!);
  final minLat = lats.reduce((a, b) => a < b ? a : b);
  final maxLat = lats.reduce((a, b) => a > b ? a : b);
  final minLng = lngs.reduce((a, b) => a < b ? a : b);
  final maxLng = lngs.reduce((a, b) => a > b ? a : b);
  double scale(double v, double lo, double hi, double outLo, double outHi) =>
      hi == lo ? (outLo + outHi) / 2 : outLo + (outHi - outLo) * (v - lo) / (hi - lo);
  return [
    for (final c in cities)
      MapSpot(
        scale(c.longitude!, minLng, maxLng, _minX, _maxX),
        // Le nord est en haut : latitude inversée.
        scale(c.latitude!, minLat, maxLat, _maxY, _minY),
      ),
  ];
}
