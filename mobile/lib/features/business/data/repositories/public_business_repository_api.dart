// Version réelle
import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../models/public_business.dart';
import 'public_business_repository.dart';

class PublicBusinessRepositoryApi implements PublicBusinessRepository {
  PublicBusinessRepositoryApi(this._dio);

  final Dio _dio;

  @override
  Future<PublicBusiness> get(int id) async {
    try {
      final response = await _dio.get<Object?>('/business/$id/');
      return PublicBusiness.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException(ApiErrorCode.unknown);
    }
  }
}
