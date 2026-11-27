// Réponse de /api/auth/otp/verify/ et /api/auth/refresh/

class AuthTokens {
  const AuthTokens(
      {required this.access, required this.refresh, this.isNew = false});

  final String access;
  final String refresh;

  /// Vrai si le compte vient d'être créé (absent du rafraîchissement).
  final bool isNew;

  /// Lit `{access, refresh, is_new}` ; lève [FormatException] si un jeton manque.
  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final access = json['access'];
    final refresh = json['refresh'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      throw const FormatException('Réponse de connexion incomplète');
    }
    return AuthTokens(
        access: access, refresh: refresh, isNew: json['is_new'] == true);
  }

  // Pas de jeton dans les journaux.
  @override
  String toString() => 'AuthTokens(isNew: $isNew)';
}
