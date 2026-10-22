import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/settings/data/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_test_helpers.dart';

void main() {
  testWidgets('par défaut : français et thème Automatique', (tester) async {
    await pumpSettingsApp(tester, store: MemorySettingsStore());
    expect(materialApp(tester).locale, const Locale('fr'));
    expect(materialApp(tester).themeMode, ThemeMode.system);
    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Automatique'), findsOneWidget);
  });

  testWidgets('English : toute l\'application change tout de suite, sur plusieurs écrans',
      (tester) async {
    final store = MemorySettingsStore();
    await pumpSettingsApp(tester, store: store, initialLocation: Routes.profile);
    await tester.ensureVisible(find.byKey(const ValueKey('profile-settings')));
    await tester.tap(find.byKey(const ValueKey('profile-settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('language-en')));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Réglages'), findsNothing);
    expect(find.text('Light'), findsOneWidget);
    expect(materialApp(tester).locale, const Locale('en'));

    // Écran suivant : À propos.
    await tester.tap(find.byKey(const ValueKey('settings-about')));
    await tester.pumpAndSettle();
    expect(find.text('About'), findsWidgets);
    expect(find.text('Legal notice'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pumpAndSettle();

    // Profil et barre du bas.
    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Log out'));
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsNothing);
    expect(find.text('Home'), findsOneWidget);

    // Retour au français : tout redevient français.
    await tester.tap(find.byKey(const ValueKey('profile-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('language-fr')));
    await tester.pumpAndSettle();
    expect(find.text('Réglages'), findsOneWidget);
  });

  testWidgets('la connexion aussi s\'affiche en anglais', (tester) async {
    final store = MemorySettingsStore(stored: const AppSettings(language: 'en'));
    await pumpSettingsApp(tester, store: store, initialLocation: Routes.login, signedIn: false);
    expect(materialApp(tester).locale, const Locale('en'));
    expect(find.text('Terms of use'), findsOneWidget);
    expect(find.text('Conditions d\'utilisation'), findsNothing);
  });

  testWidgets('langue et thème persistent après un redémarrage simulé', (tester) async {
    final store = MemorySettingsStore();
    await pumpSettingsApp(tester, store: store);
    await tester.tap(find.byKey(const ValueKey('language-en')));
    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();
    expect(store.stored, const AppSettings(language: 'en', themeMode: ThemeMode.dark));

    await closeApp(tester);
    await pumpSettingsApp(tester, store: store);

    expect(materialApp(tester).locale, const Locale('en'));
    expect(materialApp(tester).themeMode, ThemeMode.dark);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('thème Automatique : suit le téléphone ; Clair et Sombre l\'ignorent', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await pumpSettingsApp(tester, store: MemorySettingsStore());
    Brightness shown() => Theme.of(tester.element(find.text('Réglages'))).brightness;
    expect(shown(), Brightness.dark);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(shown(), Brightness.light);

    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();
    expect(shown(), Brightness.dark);

    await tester.tap(find.byKey(const ValueKey('theme-light')));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(shown(), Brightness.light);
  });

  testWidgets('stockage en échec : défauts, et le choix reste appliqué sans erreur', (tester) async {
    final store = MemorySettingsStore(failing: true);
    await pumpSettingsApp(tester, store: store);
    expect(materialApp(tester).locale, const Locale('fr'));
    expect(materialApp(tester).themeMode, ThemeMode.system);

    await tester.tap(find.byKey(const ValueKey('language-en')));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(store.saves, 1);
  });

  group('SharedSettingsStore (vrai stockage)', () {
    test('écrit puis relit les deux réglages', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedSettingsStore();
      expect(await store.load(), const AppSettings());
      await store.save(const AppSettings(language: 'en', themeMode: ThemeMode.light));
      expect(await SharedSettingsStore().load(),
          const AppSettings(language: 'en', themeMode: ThemeMode.light));
    });

    test('valeurs inconnues ou abîmées : défauts', () async {
      SharedPreferences.setMockInitialValues({
        SharedSettingsStore.languageKey: 'xx',
        SharedSettingsStore.themeKey: 'rose',
      });
      expect(await SharedSettingsStore().load(), const AppSettings());
    });

    test('stockage qui plante : défauts, pas d\'exception', () async {
      SharedPreferences.setMockInitialValues({SharedSettingsStore.languageKey: 5});
      expect(await SharedSettingsStore().load(), const AppSettings());
    });
  });
}
