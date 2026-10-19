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
      {this.message = '',
      this.statusCode,
      this.retryAfter,
      this.fieldNames = const [],
      this.serverCode = ''});

  final ApiErrorCode code;
  final String message;
  final int? statusCode;
  final Duration? retryAfter;

  /// Code du serveur tel qu'il a été reçu (`business_exists`, `throttled`,
  /// `SUBSCRIPTION_REQUIRED`, `invalid_token`…), comparé avec [ServerCodes]. Vide si absent.
  final String serverCode;

  /// Noms des champs refusés (clés de `fields` d'un 400 `invalid`) : jamais leurs valeurs.
  final List<String> fieldNames;

  /// Convertit une erreur Dio. Le corps attendu est `{"code": …, "message": …}`.
  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    if (response == null) return const ApiException(ApiErrorCode.network);
    final data = response.data;
    String? code;
    var message = '';
    var fieldNames = const <String>[];
    if (data is Map) {
      final fields = data['fields'];
      if (fields is Map) {
        fieldNames = List.unmodifiable([for (final k in fields.keys) '$k']);
      }
      code = data['code'] is String ? data['code'] as String : null;
      message = data['message'] is String ? data['message'] as String : '';
    }
    final seconds = int.tryParse(response.headers.value('retry-after') ?? '');
    return ApiException(
      ApiErrorCode.fromValue(code),
      message: message,
      statusCode: response.statusCode,
      retryAfter: seconds == null ? null : Duration(seconds: seconds),
      fieldNames: fieldNames,
      serverCode: code ?? '',
    );
  }

  @override
  String toString() => 'ApiException(${code.value}, $statusCode)';
}

/// Codes du serveur propres à la création du compte business et aux envois de fichiers.
class ServerCodes {
  const ServerCodes._();

  static const businessExists = 'business_exists';
  static const noBusiness = 'no_business';
  static const subscriptionRequired = 'SUBSCRIPTION_REQUIRED';
  static const throttled = 'throttled';
  static const invalidType = 'invalid_type';
  static const tooLarge = 'too_large';
  static const invalidContent = 'invalid_content';
  static const invalidToken = 'invalid_token';
  static const alreadyUsed = 'already_used';
}
