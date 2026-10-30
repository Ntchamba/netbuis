import 'package:shared_preferences/shared_preferences.dart';

/// La ville choisie par la personne (identifiant et nom). Ni jeton ni donnée sensible.
class SelectedCity {
  const SelectedCity({required this.id, required this.name});

  final int id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is SelectedCity && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// Préférences simples, non sensibles (jamais de jeton : ils vont dans le stockage sécurisé).
abstract class AppPrefs {
  /// Vrai quand la Découverte a déjà été vue (ou passée).
  Future<bool> isOnboardingSeen();

  Future<void> markOnboardingSeen();

  /// La ville mémorisée, ou null si aucune n'a été choisie.
  Future<SelectedCity?> getCity();

  Future<void> saveCity(SelectedCity city);
}

/// Implémentation réelle, au-dessus de `shared_preferences`.
class SharedAppPrefs implements AppPrefs {
  static const onboardingSeenKey = 'onboarding_seen';
  static const cityIdKey = 'city_id';
  static const cityNameKey = 'city_name';

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

  @override
  Future<SelectedCity?> getCity() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(cityIdKey);
    final name = prefs.getString(cityNameKey);
    if (id == null || name == null || name.isEmpty) return null;
    return SelectedCity(id: id, name: name);
  }

  @override
  Future<void> saveCity(SelectedCity city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(cityIdKey, city.id);
    await prefs.setString(cityNameKey, city.name);
  }
}
