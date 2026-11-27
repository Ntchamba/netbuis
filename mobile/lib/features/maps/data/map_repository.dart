// Contrat du dépôt de la carte par zones (sans GPS)
import '../../search/data/models/search_result.dart';
import 'models/map_models.dart';

abstract class MapRepository {
  /// GET /api/map/cities/ — seulement les villes ayant au moins un commerce actif.
  /// [q] filtre par nom côté serveur. Lève `ApiException`.
  Future<MapCities> cities({String q = ''});

  /// GET /api/map/cities/{id}/areas/ — quartiers avec compteurs. Lève `ApiException`.
  Future<MapAreas> areas(int cityId);

  /// GET /api/map/areas/{id}/businesses/ — commerces d'un quartier (même format que la
  /// recherche, sans numéro). Utilisé par l'écran Quartier (T062).
  Future<SearchPage> areaBusinesses(int areaId, {int page = 1});
}
