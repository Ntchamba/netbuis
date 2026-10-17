// Renouvelle le jeton d'accès sur un 401 puis rejoue la requête une seule fois
import 'package:dio/dio.dart';

import '../endpoints.dart';

/// Résultat d'une tentative de renouvellement de la session.
enum RefreshOutcome {
  /// Nouveau couple de jetons enregistré.
  renewed,

  /// Le serveur a refusé (ou plus de jeton) : la session est fermée.
  rejected,

  /// Réseau coupé : la session est conservée, rien n'a changé.
  offline,
}

/// Clé de `RequestOptions.extra` posée sur une requête déjà rejouée.
const String retriedExtraKey = 'retried';

/// Routes qui ne déclenchent jamais de renouvellement.
const Set<String> _neverRefresh = {
  Endpoints.otpRequest,
  Endpoints.otpVerify,
  Endpoints.refresh,
  Endpoints.logout,
};

class RefreshInterceptor extends Interceptor {
  RefreshInterceptor({
    required Dio dio,
    required Future<String?> Function() readAccessToken,
    required Future<RefreshOutcome> Function() refreshSession,
  })  : _dio = dio,
        _readAccessToken = readAccessToken,
        _refreshSession = refreshSession;

  final Dio _dio;
  final Future<String?> Function() _readAccessToken;

  /// Doit partager un seul appel réseau entre appelants simultanés.
  final Future<RefreshOutcome> Function() _refreshSession;

  static bool _excluded(String path) {
    final clean = path.split('?').first;
    return _neverRefresh.any((p) => clean == p || clean.endsWith('/api$p'));
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        request.extra[retriedExtraKey] == true ||
        _excluded(request.path)) {
      handler.next(err);
      return;
    }

    final sent = _bearer(request.headers['Authorization']);
    final current = await _readAccessToken();
    // Un renouvellement vient d'aboutir pendant que la requête était en vol.
    final alreadyRenewed =
        current != null && current.isNotEmpty && current != sent;
    if (!alreadyRenewed) {
      final outcome = await _refreshSession();
      if (outcome == RefreshOutcome.rejected) {
        handler.next(err);
        return;
      }
      if (outcome == RefreshOutcome.offline) {
        handler.next(DioException(
          requestOptions: request,
          type: DioExceptionType.connectionError,
        ));
        return;
      }
    }

    final fresh = await _readAccessToken();
    if (fresh == null || fresh.isEmpty) {
      handler.next(err);
      return;
    }
    try {
      final replayed = await _dio.fetch<Object?>(request.copyWith(
        headers: {...request.headers, 'Authorization': 'Bearer $fresh'},
        extra: {...request.extra, retriedExtraKey: true},
      ));
      handler.resolve(replayed);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  static String? _bearer(Object? header) {
    if (header is! String) return null;
    const prefix = 'Bearer ';
    return header.startsWith(prefix) ? header.substring(prefix.length) : header;
  }
}
