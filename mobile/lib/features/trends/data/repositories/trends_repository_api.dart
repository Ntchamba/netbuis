// Version réelle (GET /api/trends/)
import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../models/trend.dart';
import 'trends_repository.dart';

class TrendsRepositoryApi implements TrendsRepository {
  TrendsRepositoryApi(this._dio);

  final Dio _dio;

  /// Chemin relatif à `Env.apiUrl` (qui se termine déjà par `/api`).
  static const String path = '/trends/';

  @override
  Future<Trends> getTrends(int zone) async {
    try {
      final response = await _dio.get<Object?>(path, queryParameters: {'zone': zone});
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiException(ApiErrorCode.unknown);
      }
      return Trends.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException(ApiErrorCode.unknown);
    }
  }
}
