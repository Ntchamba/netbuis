// Ajoute « Authorization: Bearer <jeton d'accès> » quand un jeton existe
import 'package:dio/dio.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._readAccessToken);

  final Future<String?> Function() _readAccessToken;

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _readAccessToken();
    if (token != null &&
        token.isNotEmpty &&
        !options.headers.containsKey('Authorization')) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
