// Version factice (USE_FAKE_API) : trois villes actives sans coordonnées (placement en grille),
// Maroua avec quatre quartiers. Aucun réseau, aucun numéro.
import '../../../core/network/api_exception.dart';
import '../../search/data/models/search_result.dart';
import 'map_repository.dart';
import 'models/map_models.dart';

class MapRepositoryFake implements MapRepository {
  static const _extremeNord = MapNode(id: 201, name: 'Région Extrême-Nord', explorable: true);
  static const _nord = MapNode(id: 202, name: 'Région Nord', explorable: true);
  static const _littoral = MapNode(id: 203, name: 'Région Littoral', explorable: true);

  static const List<MapCity> _cities = [
    MapCity(id: 16, name: 'Maroua', businessesCount: 91, region: _extremeNord),
    MapCity(id: 17, name: 'Garoua', businessesCount: 14, region: _nord),
    MapCity(id: 18, name: 'Douala', businessesCount: 8, region: _littoral),
  ];

  static const List<MapArea> _marouaAreas = [
    MapArea(id: 301, name: 'Hardé', businessesCount: 24, productsCount: 61),
    MapArea(id: 302, name: 'Dougoï', businessesCount: 38, productsCount: 94),
    MapArea(id: 303, name: 'Domayo', businessesCount: 17, productsCount: 42),
    MapArea(id: 304, name: 'Djarengol', businessesCount: 12, productsCount: 29),
  ];

  static String _fold(String s) => s.toLowerCase();

  @override
  Future<MapCities> cities({String q = ''}) async {
    final needle = _fold(q.trim());
    return MapCities(
      cities: [for (final c in _cities) if (_fold(c.name).contains(needle)) c],
      regions: const [
        MapRegion(id: 201, name: 'Région Extrême-Nord', explorable: true),
        MapRegion(id: 202, name: 'Région Nord', explorable: true),
        MapRegion(id: 203, name: 'Région Littoral', explorable: true),
      ],
    );
  }

  @override
  Future<MapAreas> areas(int cityId) async {
    final city = _cities.where((c) => c.id == cityId);
    if (city.isEmpty) throw const ApiException(ApiErrorCode.unknown, statusCode: 404);
    final isMaroua = cityId == 16;
    return MapAreas(
      cityId: cityId,
      cityName: city.first.name,
      areas: isMaroua ? _marouaAreas : const [],
      businessesWithoutArea: isMaroua ? 0 : city.first.businessesCount,
    );
  }

  @override
  Future<SearchPage> areaBusinesses(int areaId, {int page = 1}) async =>
      const SearchPage(count: 0, results: [], hasNext: false);
}
