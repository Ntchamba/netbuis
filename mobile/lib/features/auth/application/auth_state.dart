// États de la connexion
import '../../../core/network/api_exception.dart';

sealed class AuthState {
  const AuthState();
}

/// Pas de session.
class AuthLoggedOut extends AuthState {
  const AuthLoggedOut();
}

/// Requête en cours (envoi du code, vérification, restauration, déconnexion).
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Code envoyé par SMS.
class AuthCodeSent extends AuthState {
  const AuthCodeSent(
      {required this.expiresIn,
      required this.expiresAt,
      required this.resendAvailableAt});

  /// Validité annoncée par le serveur.
  final Duration expiresIn;
  final DateTime expiresAt;

  /// Moment à partir duquel « Renvoyer le code » est proposé.
  final DateTime resendAvailableAt;
}

/// Session ouverte.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({this.isNew = false});

  /// Vrai juste après la création du compte (T011b : demander le nom).
  final bool isNew;
}

/// Échec ; [hasPendingCode] indique qu'un code a été envoyé et qu'on peut réessayer de le saisir.
class AuthFailure extends AuthState {
  const AuthFailure(this.code,
      {this.message = '', this.retryAfter, this.hasPendingCode = false});

  final ApiErrorCode code;
  final String message;
  final Duration? retryAfter;
  final bool hasPendingCode;
}
