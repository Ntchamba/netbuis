import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fonctions activables. Tout ce qui est reporté (décisions D-16, V01…V10) reste faux.
class FeatureFlags {
  const FeatureFlags._();

  /// Équipe NetBuis et parrainage (reporté, V01). Faux : la 5ᵉ diapositive
  /// de la Découverte parle du compte business.
  static const bool teamEnabled = false;

  /// Crédits et paiements (reporté, D-16, `CREDITS_ENABLED=False`).
  static const bool creditsEnabled = false;
}

/// Crédits activés ? Remplaçable dans les tests (FAQ, Profil).
final creditsEnabledProvider = Provider<bool>((ref) => FeatureFlags.creditsEnabled);
