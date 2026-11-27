import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:netbuis/core/network/dio_client.dart';

/// Faux serveur qui garde les requêtes complètes (chemin et paramètres d'URL).
class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.handler);

  final ({int status, Object? body}) Function(RequestOptions) handler;
  final List<RequestOptions> seen = [];

  static ({int status, Object? body}) ok(Object? body) => (status: 200, body: body);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    final r = handler(options);
    return ResponseBody.fromString(jsonEncode(r.body), r.status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

/// Client Dio branché sur [adapter], sans réseau.
Dio dioWith(RecordingAdapter adapter) {
  final dio = buildDio(baseUrl: 'http://test/api', readAccessToken: () async => null);
  dio.httpClientAdapter = adapter;
  return dio;
}
