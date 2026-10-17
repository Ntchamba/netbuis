// Version factice (USE_FAKE_API) : aucun réseau
import '../../../../core/network/api_exception.dart';
import '../models/auth_tokens.dart';
import '../models/otp_request.dart';
import 'auth_repository.dart';

/// Reproduit les réponses du vrai serveur. Le code accepté est toujours `123456`.
class AuthRepositoryFake implements AuthRepository {
  AuthRepositoryFake();

  static const acceptedCode = '123456';
  static const codeLifetime = Duration(minutes: 5);

  final Set<String> _knownPhones = {};
  static const _refreshPrefix = 'fake-refresh-';
  int _counter = 0;

  static final RegExp _phone = RegExp(r'^(\+?237)?6\d{8}$');

  String _normalize(String raw) {
    final compact = raw.replaceAll(RegExp(r'[\s.-]'), '');
    if (!_phone.hasMatch(compact)) {
      throw const ApiException(
        ApiErrorCode.invalidPhone,
        message:
            'Numéro invalide. Entrez un numéro mobile camerounais à 9 chiffres commençant par 6.',
        statusCode: 400,
      );
    }
    return '+237${compact.substring(compact.length - 9)}';
  }

  AuthTokens _newTokens({bool isNew = false}) {
    _counter++;
    final refresh = '$_refreshPrefix$_counter';
    return AuthTokens(
        access: 'fake-access-$_counter', refresh: refresh, isNew: isNew);
  }

  @override
  Future<OtpRequest> requestOtp(String phone) async {
    _normalize(phone);
    return const OtpRequest(expiresIn: codeLifetime);
  }

  @override
  Future<AuthTokens> verifyOtp(
      {required String phone, required String code}) async {
    final normalized = _normalize(phone);
    if (code != acceptedCode) {
      throw const ApiException(
        ApiErrorCode.otpInvalid,
        message: 'Code incorrect. Vérifiez le code reçu par SMS.',
        statusCode: 400,
      );
    }
    final isNew = _knownPhones.add(normalized);
    return _newTokens(isNew: isNew);
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    // Tout jeton « fake-refresh-… » est accepté : il doit survivre à un redémarrage de l'appli.
    if (!refreshToken.startsWith(_refreshPrefix)) {
      throw const ApiException(
        ApiErrorCode.tokenInvalid,
        message: 'Session expirée. Reconnectez-vous.',
        statusCode: 401,
      );
    }
    return _newTokens();
  }

  @override
  Future<void> logout(String refreshToken) async {
    if (!refreshToken.startsWith(_refreshPrefix)) {
      throw const ApiException(
        ApiErrorCode.tokenInvalid,
        message: 'Session expirée. Reconnectez-vous.',
        statusCode: 401,
      );
    }
  }
}
