// Version réelle : POST /api/calls/initiate/
import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../models/call_session.dart';
import 'call_repository.dart';

class CallRepositoryApi implements CallRepository {
  CallRepositoryApi(this._dio);

  final Dio _dio;

  /// Chemin relatif à `Env.apiUrl`.
  static const String path = '/calls/initiate/';

  @override
  Future<CallSession> initiate({required int businessId, CallLine? line}) async {
    try {
      final response = await _dio.post<Object?>(path, data: {
        'business_id': businessId,
        'channel': 'call',
        'platform': 'android',
        if (line != null) 'operator': line.value,
      });
      return CallSession.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      // Message volontairement vide de détail : le corps de la réponse contient le numéro.
      throw const ApiException(ApiErrorCode.unknown);
    }
  }
}
