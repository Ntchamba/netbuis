// Toutes les routes /api/… en un seul endroit

/// Chemins relatifs à `Env.apiUrl` (qui se termine déjà par `/api`).
class Endpoints {
  const Endpoints._();

  static const String otpRequest = '/auth/otp/request/';
  static const String otpVerify = '/auth/otp/verify/';
  static const String refresh = '/auth/refresh/';
  static const String logout = '/auth/logout/';
  static const String me = '/me/';
}
