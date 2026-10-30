import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Réglages choisis par la personne : langue de l'interface et thème.
class AppSettings {
  const AppSettings({this.language = defaultLanguage, this.themeMode = ThemeMode.system});

  static const defaultLanguage = 'fr';
  static const supportedLanguages = ['fr', 'en'];

  /// Code de langue : `fr` ou `en` (français tant que rien n'est choisi).
  final String language;

  /// Clair, sombre ou automatique (suit le téléphone).
  final ThemeMode themeMode;

  Locale get locale => Locale(language);

  AppSettings copyWith({String? language, ThemeMode? themeMode}) =>
      AppSettings(language: language ?? this.language, themeMode: themeMode ?? this.themeMode);

  @override
  bool operator ==(Object other) =>
      other is AppSettings && other.language == language && other.themeMode == themeMode;

  @override
  int get hashCode => Object.hash(language, themeMode);
}

/// Mémoire des réglages. Ne lève jamais d'erreur : si le stockage échoue, on garde les défauts.
abstract class SettingsStore {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}

/// Version réelle, au-dessus de `shared_preferences` (aucune donnée sensible).
class SharedSettingsStore implements SettingsStore {
  static const languageKey = 'settings_language';
  static const themeKey = 'settings_theme';

  @override
  Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final language = prefs.getString(languageKey);
      final theme = prefs.getString(themeKey);
      return AppSettings(
        language: AppSettings.supportedLanguages.contains(language)
            ? language!
            : AppSettings.defaultLanguage,
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == theme,
          orElse: () => ThemeMode.system,
        ),
      );
    } on Object {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(languageKey, settings.language);
      await prefs.setString(themeKey, settings.themeMode.name);
    } on Object {
      // Stockage indisponible : le réglage reste appliqué jusqu'à la fermeture de l'application.
    }
  }
}
