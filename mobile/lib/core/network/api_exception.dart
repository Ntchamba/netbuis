// Erreurs réseau lisibles
import 'package:dio/dio.dart';

/// Codes d'erreur renvoyés par le serveur (champ `code`), plus deux cas locaux.
enum ApiErrorCode {
  invalidPhone('invalid_phone'),
  otpInvalid('otp_invalid'),
  otpExpired('otp_expired'),
  tooManyRequests('too_many_requests'),
  accountBlocked('account_blocked'),
  accountDeleted('account_deleted'),
  tokenInvalid('token_invalid'),
  invalid('invalid'),

  /// Pas de réponse du serveur (réseau coupé, délai dépassé).
  network('network'),

  /// Tout autre code ou réponse illisible.
  unknown('unknown');

  const ApiErrorCode(this.value);
  final String value;

  static ApiErrorCode fromValue(String? value) {
    for (final c in ApiErrorCode.values) {
      if (c.value == value && c != network && c != unknown) return c;
    }
    return unknown;
  }
}

/// Erreur d'API : code typé, message court du serveur, attente éventuelle (Retry-After).
/// Ne contient jamais de jeton ni de numéro.
class ApiException implements Exception {
  const ApiException(this.code,
      {this.message = '', this.statusCode, this.retryAfter});

  final ApiErrorCode code;
  final String message;
  final int? statusCode;
  final Duration? retryAfter;

  /// Convertit une erreur Dio. Le corps attendu est `{"code": …, "message": …}`.
  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    if (response == null) return const ApiException(ApiErrorCode.network);
    final data = response.data;
    String? code;
    var message = '';
    if (data is Map) {
      code = data['code'] is String ? data['code'] as String : null;
      message = data['message'] is String ? data['message'] as String : '';
    }
    final seconds = int.tryParse(response.headers.value('retry-after') ?? '');
    return ApiException(
      ApiErrorCode.fromValue(code),
      message: message,
      statusCode: response.statusCode,
      retryAfter: seconds == null ? null : Duration(seconds: seconds),
    );
  }

  @override
  String toString() => 'ApiException(${code.value}, $statusCode)';
}
