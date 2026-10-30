import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/features/trends/data/repositories/trends_repository_api.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);
  final int status;
  final Object? body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
      Future<void>? cancelFuture) async {
    last = options;
    return ResponseBody.fromString(jsonEncode(body), status,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('appelle /trends/ avec la zone et lit la réponse', () async {
    final adapter = _Adapter(200, {
      'zone': {'id': 16, 'name': 'Maroua'},
      'computed_at': null,
      'period_days': 7,
      'products': [
        {'id': 1, 'name': 'Riz', 'rank': 1}
      ],
      'businesses': <Object?>[],
    });
    final dio = Dio()..httpClientAdapter = adapter;
    final t = await TrendsRepositoryApi(dio).getTrends(16);
    expect(adapter.last!.path, '/trends/');
    expect(adapter.last!.queryParameters, {'zone': 16});
    expect(t.products.single.name, 'Riz');
  });

  test('erreur serveur : ApiException', () async {
    final dio = Dio()..httpClientAdapter = _Adapter(500, {'code': 'server_error'});
    expect(TrendsRepositoryApi(dio).getTrends(16), throwsA(isA<ApiException>()));
  });

  test('réponse inattendue : ApiException', () async {
    final dio = Dio()..httpClientAdapter = _Adapter(200, ['pas', 'un', 'objet']);
    expect(TrendsRepositoryApi(dio).getTrends(16), throwsA(isA<ApiException>()));
  });
}
