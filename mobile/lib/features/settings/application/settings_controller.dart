import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_store.dart';

/// Mémoire des réglages, remplaçable dans les tests.
final settingsStoreProvider = Provider<SettingsStore>((ref) => SharedSettingsStore());

/// Réglages déjà lus avant le premier affichage (évite un éclair en français au
/// démarrage). `null` : le contrôleur les lit lui-même, juste après le démarrage.
final initialSettingsProvider = Provider<AppSettings?>((ref) => null);

/// Langue et thème en cours. Un choix s'applique tout de suite puis est mémorisé.
final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  bool _chosen = false;

  @override
  AppSettings build() {
    final initial = ref.read(initialSettingsProvider);
    if (initial != null) return initial;
    scheduleMicrotask(_load);
    return const AppSettings();
  }

  Future<void> _load() async {
    final loaded = await ref.read(settingsStoreProvider).load();
    // Si la personne a déjà choisi pendant la lecture, son choix gagne.
    if (ref.mounted && !_chosen) state = loaded;
  }

  void setLanguage(String language) {
    if (!AppSettings.supportedLanguages.contains(language)) return;
    _apply(state.copyWith(language: language));
  }

  void setThemeMode(ThemeMode mode) => _apply(state.copyWith(themeMode: mode));

  void _apply(AppSettings next) {
    _chosen = true;
    state = next;
    unawaited(ref.read(settingsStoreProvider).save(next));
  }
}
