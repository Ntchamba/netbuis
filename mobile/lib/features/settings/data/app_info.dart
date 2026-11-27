/// Nom de l'application affiché dans « À propos ».
const String appName = 'NetBuis';

/// À REMPLACER : la version est lue de la ligne `version:` de pubspec.yaml à la main, car
/// aucun paquet de lecture de version n'est installé. Elle peut être imposée au lancement
/// avec `--dart-define=APP_VERSION=...`.
const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0+1');
