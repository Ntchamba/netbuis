// Version factice (USE_FAKE_API=true) : les zones de backend/apps/geo/data/zones.csv
import '../../network/api_exception.dart';
import 'zone.dart';
import 'zone_repository.dart';

class ZoneRepositoryFake implements ZoneRepository {
  ZoneRepositoryFake() : _zones = _build();

  final List<Zone> _zones;

  static const _regions = [
    'Adamaoua',
    'Centre',
    'Est',
    'Extrême-Nord',
    'Littoral',
    'Nord',
    'Nord-Ouest',
    'Ouest',
    'Sud',
    'Sud-Ouest',
  ];
  static const _quartiers = ['Hardé', 'Dougoï', 'Domayo', 'Djarengol'];

  static List<Zone> _build() {
    final zones = <Zone>[];
    Zone add(String name, ZoneLevel level, int? parent, int order) {
      final zone = Zone(
        id: zones.length + 1,
        name: name,
        level: level,
        parent: parent,
        order: order,
      );
      zones.add(zone);
      return zone;
    }

    final country = add('Cameroun', ZoneLevel.pays, null, 1);
    final regionIds = <String, int>{};
    for (var i = 0; i < _regions.length; i++) {
      regionIds[_regions[i]] =
          add(_regions[i], ZoneLevel.region, country.id, i + 1).id;
    }
    final departement = add(
        'Diamaré', ZoneLevel.departement, regionIds['Extrême-Nord'], 1);
    for (var i = 1; i <= 3; i++) {
      add('Maroua $i', ZoneLevel.arrondissement, departement.id, i);
    }
    final maroua = add('Maroua', ZoneLevel.villeVillage, departement.id, 1);
    for (var i = 0; i < _quartiers.length; i++) {
      add(_quartiers[i], ZoneLevel.quartier, maroua.id, i + 1);
    }
    return List.unmodifiable(zones);
  }

  @override
  Future<List<Zone>> listZones({ZoneLevel? level, int? parent}) async {
    final found = _zones
        .where((z) =>
            (level == null || z.level == level) &&
            (parent == null || z.parent == parent))
        .toList()
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
      });
    return List.unmodifiable(found);
  }

  @override
  Future<ZoneDetail> getZone(int id) async {
    final byId = {for (final z in _zones) z.id: z};
    final zone = byId[id];
    if (zone == null) {
      throw const ApiException(ApiErrorCode.unknown, statusCode: 404);
    }
    final path = <ZonePathItem>[];
    for (Zone? z = zone; z != null; z = z.parent == null ? null : byId[z.parent]) {
      path.insert(0, ZonePathItem(id: z.id, name: z.name, level: z.level));
    }
    return ZoneDetail(zone: zone, path: List.unmodifiable(path));
  }
}
