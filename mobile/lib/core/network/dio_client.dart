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

/// Client des ENVOIS DE FICHIERS (PUT vers l'adresse donnée par `POST /api/uploads/sign/`).
///
/// Volontairement **sans** intercepteur : ni `Authorization` (le jeton signé de l'adresse fait
/// foi ; une adresse présignée S3 refuserait un en-tête de plus), ni renouvellement de
/// session. Mêmes délais que le client principal. Aucune adresse de base : l'adresse est
/// toujours complète (voir `resolveUploadUrl`).
Dio buildUploadDio() {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
    ),
  );
}
