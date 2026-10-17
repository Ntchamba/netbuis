// Version réelle
import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/endpoints.dart';
import '../models/me.dart';
import 'account_repository.dart';

class AccountRepositoryApi implements AccountRepository {
  AccountRepositoryApi(this._dio);

  final Dio _dio;

  Me _parse(Object? data) {
    try {
      if (data is Map<String, dynamic>) return Me.fromJson(data);
    } on FormatException {
      // tombe sur l'erreur ci-dessous
    }
    throw const ApiException(ApiErrorCode.unknown);
  }

  @override
  Future<Me> getMe() async {
    try {
      final response = await _dio.get<Object?>(Endpoints.me);
      return _parse(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Me> updateName(String name) async {
    try {
      final response =
          await _dio.patch<Object?>(Endpoints.me, data: {'name': name});
      return _parse(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
