// Interface
import '../models/auth_tokens.dart';
import '../models/otp_request.dart';

/// Connexion par code SMS. Toutes les méthodes lèvent `ApiException` en cas d'erreur.
abstract class AuthRepository {
  /// Demande l'envoi d'un code au numéro (6XXXXXXXX, avec ou sans +237).
  Future<OtpRequest> requestOtp(String phone);

  /// Vérifie le code ; renvoie les jetons.
  Future<AuthTokens> verifyOtp({required String phone, required String code});

  /// Échange le jeton de rafraîchissement contre un nouveau couple
  /// (l'ancien refresh n'est plus valable : il faut enregistrer le nouveau).
  Future<AuthTokens> refresh(String refreshToken);

  /// Invalide le jeton de rafraîchissement côté serveur.
  Future<void> logout(String refreshToken);
}
