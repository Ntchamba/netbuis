// Version réelle
import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/endpoints.dart';
import '../models/auth_tokens.dart';
import '../models/otp_request.dart';
import 'auth_repository.dart';

class AuthRepositoryApi implements AuthRepository {
  AuthRepositoryApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Object?>(path, data: body);
      final data = response.data;
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  T _parse<T>(T Function() read) {
    try {
      return read();
    } on FormatException {
      throw const ApiException(ApiErrorCode.unknown);
    }
  }

  @override
  Future<OtpRequest> requestOtp(String phone) async {
    final data = await _post(Endpoints.otpRequest, {'phone': phone});
    return _parse(() => OtpRequest.fromJson(data));
  }

  @override
  Future<AuthTokens> verifyOtp(
      {required String phone, required String code}) async {
    final data =
        await _post(Endpoints.otpVerify, {'phone': phone, 'code': code});
    return _parse(() => AuthTokens.fromJson(data));
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    final data = await _post(Endpoints.refresh, {'refresh': refreshToken});
    return _parse(() => AuthTokens.fromJson(data));
  }

  @override
  Future<void> logout(String refreshToken) async {
    await _post(Endpoints.logout, {'refresh': refreshToken});
  }
}
