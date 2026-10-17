import 'package:shared_preferences/shared_preferences.dart';

/// Préférences simples, non sensibles (jamais de jeton : ils vont dans le stockage sécurisé).
abstract class AppPrefs {
  /// Vrai quand la Découverte a déjà été vue (ou passée).
  Future<bool> isOnboardingSeen();

  Future<void> markOnboardingSeen();
}

/// Implémentation réelle, au-dessus de `shared_preferences`.
class SharedAppPrefs implements AppPrefs {
  static const onboardingSeenKey = 'onboarding_seen';

  @override
  Future<bool> isOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(onboardingSeenKey) ?? false;
  }

  @override
  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingSeenKey, true);
  }
}
