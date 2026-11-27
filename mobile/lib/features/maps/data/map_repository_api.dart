// Version réelle : /api/map/…
import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../search/data/models/search_result.dart';
import 'map_repository.dart';
import 'models/map_models.dart';

class MapRepositoryApi implements MapRepository {
  MapRepositoryApi(this._dio);

  final Dio _dio;

  Future<T> _get<T>(String path, T Function(Object?) parse, {Map<String, Object?>? query}) async {
    try {
      final response = await _dio.get<Object?>(path, queryParameters: query);
      return parse(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException(ApiErrorCode.unknown);
    }
  }

  @override
  Future<MapCities> cities({String q = ''}) => _get(
        '/map/cities/',
        MapCities.fromJson,
        query: q.trim().isEmpty ? null : {'q': q.trim()},
      );

  @override
  Future<MapAreas> areas(int cityId) => _get('/map/cities/$cityId/areas/', MapAreas.fromJson);

  @override
  Future<SearchPage> areaBusinesses(int areaId, {int page = 1}) =>
      _get('/map/areas/$areaId/businesses/', SearchPage.fromJson, query: {'page': page});
}
