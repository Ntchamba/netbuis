// Client Dio unique
import 'package:dio/dio.dart';

import 'interceptors/auth_interceptor.dart';

/// Client HTTP de l'application : délai de 15 s, JSON, jeton d'accès en Bearer.
Dio buildDio(
    {required String baseUrl,
    required Future<String?> Function() readAccessToken}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );
  dio.interceptors.add(AuthInterceptor(readAccessToken));
  return dio;
}
