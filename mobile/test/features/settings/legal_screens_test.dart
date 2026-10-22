import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/settings/data/app_info.dart';
import 'package:netbuis/features/settings/data/settings_store.dart';

import 'settings_test_helpers.dart';

void main() {
  for (final lang in ['fr', 'en']) {
    for (final entry in {
      Routes.legalNotice: 'legal.notice',
      Routes.terms: 'legal.terms',
      Routes.privacy: 'legal.privacy',
    }.entries) {
      testWidgets('page ${entry.key} ($lang) : texte provisoire marqué À REMPLACER', (tester) async {
        await pumpSettingsApp(tester,
            store: MemorySettingsStore(stored: AppSettings(language: lang)),
            initialLocation: entry.key);
        final body = tester.widget<Text>(find.byKey(const ValueKey('legal-body')));
        expect(body.data, contains('À REMPLACER'));
      });
    }
  }

  testWidgets('À propos : nom et version', (tester) async {
    await pumpSettingsApp(tester, store: MemorySettingsStore(), initialLocation: Routes.about);
    expect(find.text(appName), findsOneWidget);
    expect(find.text('Version $appVersion'), findsOneWidget);
  });

  testWidgets('Connexion (sans session) : les liens ouvrent les pages légales, et le retour revient',
      (tester) async {
    await pumpSettingsApp(tester,
        store: MemorySettingsStore(), initialLocation: Routes.login, signedIn: false);
    await tester.tap(find.byKey(const ValueKey('legal-link-terms')));
    await tester.pumpAndSettle();
    expect(find.text('Conditions d\'utilisation'), findsOneWidget);
    expect(find.byKey(const ValueKey('legal-body')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('legal-link-privacy')));
    await tester.pumpAndSettle();
    expect(find.text('Politique de confidentialité'), findsOneWidget);
    expect(find.byKey(const ValueKey('legal-body')), findsOneWidget);
  });

  testWidgets('depuis Réglages puis À propos : trois pages légales accessibles', (tester) async {
    await pumpSettingsApp(tester, store: MemorySettingsStore());
    for (final key in ['settings-legal', 'settings-terms', 'settings-privacy']) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('legal-body')), findsOneWidget, reason: key);
      await tester.tap(find.byKey(const ValueKey('settings-back')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('settings-about')));
    await tester.pumpAndSettle();
    for (final key in ['about-legal', 'about-terms', 'about-privacy']) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('legal-body')), findsOneWidget, reason: key);
      await tester.tap(find.byKey(const ValueKey('settings-back')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Profil : l\'entrée Réglages mène à l\'écran Réglages', (tester) async {
    await pumpSettingsApp(tester, store: MemorySettingsStore(), initialLocation: Routes.profile);
    await tester.ensureVisible(find.byKey(const ValueKey('profile-settings')));
    await tester.tap(find.byKey(const ValueKey('profile-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('language-fr')), findsOneWidget);
  });

  testWidgets('un écran protégé reste protégé : Réglages sans session mène à la connexion',
      (tester) async {
    await pumpSettingsApp(tester,
        store: MemorySettingsStore(), initialLocation: Routes.settings, signedIn: false);
    expect(find.byKey(const ValueKey('language-fr')), findsNothing);
    expect(find.byKey(const ValueKey('legal-link-terms')), findsOneWidget);
  });
}
