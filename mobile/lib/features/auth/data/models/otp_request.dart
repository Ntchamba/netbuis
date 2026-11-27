// Réponse de /api/auth/otp/request/

class OtpRequest {
  const OtpRequest({required this.expiresIn});

  /// Validité du code envoyé.
  final Duration expiresIn;

  /// Lit `{expires_in}` (secondes) ; lève [FormatException] sinon.
  factory OtpRequest.fromJson(Map<String, dynamic> json) {
    final seconds = json['expires_in'];
    if (seconds is! int || seconds <= 0) {
      throw const FormatException('Durée de validité du code absente');
    }
    return OtpRequest(expiresIn: Duration(seconds: seconds));
  }
}
