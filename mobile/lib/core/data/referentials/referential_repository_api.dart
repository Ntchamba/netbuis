// Version réelle
import 'package:dio/dio.dart';

import '../../network/api_exception.dart';
import '../../network/endpoints.dart';
import 'referential_models.dart';
import 'referential_repository.dart';

class ReferentialRepositoryApi implements ReferentialRepository {
  ReferentialRepositoryApi(this._dio);

  final Dio _dio;

  /// Lit un tableau JSON et convertit chaque élément ; toute anomalie devient
  /// une erreur `unknown`, un échec réseau une erreur typée.
  Future<List<T>> _getList<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get<Object?>(path, queryParameters: query);
      final data = response.data;
      if (data is! List) throw const ApiException(ApiErrorCode.unknown);
      return List.unmodifiable([
        for (final item in data)
          if (item is Map<String, dynamic>)
            parse(item)
          else
            throw const ApiException(ApiErrorCode.unknown),
      ]);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException(ApiErrorCode.unknown);
    }
  }

  @override
  Future<List<Sector>> getSectors() => _getList(Endpoints.sectors, Sector.fromJson);

  @override
  Future<List<ReferentialItem>> getServiceCategories() =>
      _getList(Endpoints.serviceCategories, ReferentialItem.fromJson);

  @override
  Future<List<ReferentialItem>> getStructureTypes() =>
      _getList(Endpoints.structureTypes, ReferentialItem.fromJson);

  @override
  Future<List<CatalogProduct>> searchProducts(String query) async {
    final q = query.trim();
    if (q.isEmpty || q.length > maxProductQueryLength) {
      throw const ApiException(ApiErrorCode.invalid, statusCode: 400);
    }
    return await _getList(Endpoints.catalogProducts, CatalogProduct.fromJson,
        query: {'q': q});
  }
}
