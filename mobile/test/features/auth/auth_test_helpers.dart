import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/storage/secure_storage.dart';
import 'package:netbuis/features/auth/data/models/auth_tokens.dart';
import 'package:netbuis/features/auth/data/models/otp_request.dart';
import 'package:netbuis/features/auth/data/repositories/auth_repository.dart';

/// Stockage en mémoire (aucun accès disque).
class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage({String? access, String? refresh})
      : _access = access,
        _refresh = refresh;

  String? _access;
  String? _refresh;
  bool throwOnRead = false;

  @override
  Future<StoredTokens> read() async {
    if (throwOnRead) throw StateError('stockage illisible');
    return StoredTokens(access: _access, refresh: _refresh);
  }

  @override
  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

/// Requête vue par le faux serveur.
class SeenRequest {
  SeenRequest(this.method, this.path, this.body, this.headers);
  final String method;
  final String path;
  final Object? body;
  final Map<String, dynamic> headers;
}

/// Faux adaptateur Dio : aucun réseau. [handler] renvoie le statut, le corps et les en-têtes,
/// ou lève une DioException pour simuler une coupure.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final ({int status, Object? body, Map<String, String> headers}) Function(
      SeenRequest) handler;
  final List<SeenRequest> seen = [];

  static ({int status, Object? body, Map<String, String> headers}) reply(
    int status,
    Object? body, {
    Map<String, String> headers = const {},
  }) =>
      (status: status, body: body, headers: headers);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final request = SeenRequest(
        options.method, options.path, options.data, options.headers);
    seen.add(request);
    final r = handler(request);
    return ResponseBody.fromString(
      jsonEncode(r.body),
      r.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        for (final e in r.headers.entries) e.key: [e.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Dépôt scénarisé pour le contrôleur.
class ScriptedRepository implements AuthRepository {
  ApiException? requestError;
  ApiException? verifyError;
  ApiException? refreshError;
  ApiException? logoutError;
  int logoutCalls = 0;
  String? lastLogoutToken;
  String? lastPhone;
  int refreshCalls = 0;

  @override
  Future<OtpRequest> requestOtp(String phone) async {
    if (requestError != null) throw requestError!;
    lastPhone = phone;
    return const OtpRequest(expiresIn: Duration(seconds: 300));
  }

  @override
  Future<AuthTokens> verifyOtp(
      {required String phone, required String code}) async {
    if (verifyError != null) throw verifyError!;
    return const AuthTokens(access: 'acc-1', refresh: 'ref-1', isNew: true);
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    refreshCalls++;
    if (refreshError != null) throw refreshError!;
    return const AuthTokens(access: 'acc-2', refresh: 'ref-2');
  }

  @override
  Future<void> logout(String refreshToken) async {
    logoutCalls++;
    lastLogoutToken = refreshToken;
    if (logoutError != null) throw logoutError!;
  }
}
