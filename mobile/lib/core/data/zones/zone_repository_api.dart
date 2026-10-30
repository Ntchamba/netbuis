// Version réelle
import 'package:dio/dio.dart';

import '../../network/api_exception.dart';
import '../../network/endpoints.dart';
import 'zone.dart';
import 'zone_repository.dart';

class ZoneRepositoryApi implements ZoneRepository {
  ZoneRepositoryApi(this._dio);

  final Dio _dio;

  /// Taille de page maximale acceptée par le serveur.
  static const int pageSize = 50;

  /// Garde-fou contre une pagination qui ne se terminerait jamais.
  static const int maxPages = 200;

  @override
  Future<List<Zone>> listZones({ZoneLevel? level, int? parent}) async {
    final zones = <Zone>[];
    try {
      for (var page = 1; page <= maxPages; page++) {
        final response = await _dio.get<Object?>(
          Endpoints.zones,
          queryParameters: {
            if (level != null) 'level': level.value,
            if (parent != null) 'parent': parent,
            'page_size': pageSize,
            'page': page,
          },
        );
        final data = response.data;
        if (data is! Map<String, dynamic> || data['results'] is! List) {
          throw const ApiException(ApiErrorCode.unknown);
        }
        for (final item in data['results'] as List) {
          if (item is! Map<String, dynamic>) {
            throw const ApiException(ApiErrorCode.unknown);
          }
          zones.add(Zone.fromJson(item));
        }
        if (data['next'] == null) return List.unmodifiable(zones);
      }
      throw const ApiException(ApiErrorCode.unknown);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException(ApiErrorCode.unknown);
    }
  }

  @override
  Future<ZoneDetail> getZone(int id) async {
    try {
      final response = await _dio.get<Object?>(Endpoints.zoneDetail(id));
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiException(ApiErrorCode.unknown);
      }
      return ZoneDetail.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException(ApiErrorCode.unknown);
    }
  }
}
