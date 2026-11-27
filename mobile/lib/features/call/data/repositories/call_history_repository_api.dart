// Version réelle : GET /api/calls/history/
import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../models/call_history_entry.dart';
import 'call_history_repository.dart';

class CallHistoryRepositoryApi implements CallHistoryRepository {
  CallHistoryRepositoryApi(this._dio);

  final Dio _dio;

  /// Chemin relatif à `Env.apiUrl`.
  static const String path = '/calls/history/';

  @override
  Future<CallHistoryPage> history({int page = 1}) async {
    try {
      final response =
          await _dio.get<Object?>(path, queryParameters: {'page': page});
      return CallHistoryPage.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException(ApiErrorCode.unknown);
    }
  }
}
