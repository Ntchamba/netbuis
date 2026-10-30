// Lecture des --dart-define (API_URL, USE_FAKE_API)
import 'package:flutter/foundation.dart';

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

  /// Valeur d'attente des coordonnées du support (décision D-06) : tant qu'elle est là,
  /// les boutons de contact sont désactivés.
  static const String toReplace = 'À REMPLACER';

  /// Coordonnées du support, fournies à la compilation
  /// (`--dart-define=SUPPORT_WHATSAPP=… SUPPORT_PHONE=… SUPPORT_EMAIL=…`). Aucune valeur réelle ici.
  static const String supportWhatsapp =
      String.fromEnvironment('SUPPORT_WHATSAPP', defaultValue: toReplace);
  static const String supportPhone =
      String.fromEnvironment('SUPPORT_PHONE', defaultValue: toReplace);
  static const String supportEmail =
      String.fromEnvironment('SUPPORT_EMAIL', defaultValue: toReplace);
}

/// Vérifie l'adresse de l'API avant tout envoi (T121).
///
/// En **release** ([release] vaut `kReleaseMode`), seule une adresse `https://` avec un hôte et
/// sans identifiants (`utilisateur:mot-de-passe@`) est acceptée : sinon [StateError] (sans
/// afficher l'adresse). En débogage, `http://` reste permis (émulateur `10.0.2.2`, poste local).
String ensureSecureApiUrl(String url, {bool release = kReleaseMode}) {
  final uri = Uri.tryParse(url);
  final valid = uri != null && uri.host.isNotEmpty && uri.userInfo.isEmpty;
  final scheme = uri?.scheme;
  if (!valid || (scheme != 'https' && scheme != 'http')) {
    throw StateError('API_URL invalide');
  }
  if (release && scheme != 'https') {
    throw StateError('API_URL doit être en https en version de production');
  }
  return url;
}
