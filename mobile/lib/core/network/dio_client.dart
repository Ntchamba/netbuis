// Client Dio unique
import 'package:dio/dio.dart';

import 'interceptors/auth_interceptor.dart';
import 'interceptors/refresh_interceptor.dart';

/// Client HTTP de l'application : délai de 15 s, JSON, jeton d'accès en Bearer,
/// renouvellement automatique sur 401 si [refreshSession] est fourni.
Dio buildDio(
    {required String baseUrl,
    required Future<String?> Function() readAccessToken,
    Future<RefreshOutcome> Function()? refreshSession}) {
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
  if (refreshSession != null) {
    dio.interceptors.add(RefreshInterceptor(
        dio: dio,
        readAccessToken: readAccessToken,
        refreshSession: refreshSession));
  }
  return dio;
}
