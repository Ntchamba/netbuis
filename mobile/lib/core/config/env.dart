// Lecture des --dart-define (API_URL, USE_FAKE_API)

/// Réglages fixés à la compilation (`--dart-define=API_URL=… --dart-define=USE_FAKE_API=true`).
class Env {
  const Env._();

  /// Adresse de l'API, `/api` compris (10.0.2.2 = le PC vu depuis l'émulateur Android).
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  /// Vrai : l'application utilise les dépôts factices, sans réseau.
  static const bool useFakeApi = bool.fromEnvironment('USE_FAKE_API');
}
