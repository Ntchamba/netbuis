// T120 : les champs où l'on saisit un nombre ouvrent le clavier numérique, sur chaque écran
// concerné (téléphone, code SMS, prix, nombre de chambres) ; un champ de nom reste au clavier texte.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a11y_harness.dart';
import 'screens.dart';

/// Clavier demandé par le champ qui porte [key] (ou qui est dans le widget qui porte [key]).
TextInputType _keyboardOf(WidgetTester tester, Key key) {
  final inside =
      find.descendant(of: find.byKey(key), matching: find.byType(EditableText));
  final field = inside.evaluate().isNotEmpty
      ? inside
      : find.ancestor(of: find.byType(EditableText), matching: find.byKey(key));
  return tester.widget<EditableText>(field.first).keyboardType;
}

bool _isNumeric(TextInputType t) =>
    t.index == TextInputType.number.index ||
    t.index == TextInputType.phone.index;

void main() {
  final withNumbers =
      a11yScreens.where((s) => s.numericKeys.isNotEmpty).toList();

  test('la liste contient téléphone, code SMS, prix et chambres', () {
    final keys = withNumbers
        .expand((s) => s.numericKeys)
        .map((k) => (k as ValueKey<String>).value);
    expect(
        keys,
        containsAll([
          'phone-field',
          'otp-field',
          'offer-price',
          'business-structure-chambres'
        ]));
  });

  for (final screen in withNumbers) {
    testWidgets('${screen.id} : champs de nombres au clavier numérique',
        (tester) async {
      await pumpA11y(tester, screen, scale: 1.0, mode: ThemeMode.dark);
      expectShown(screen);
      for (final key in screen.numericKeys) {
        await tester.ensureVisible(find.byKey(key));
        expect(_isNumeric(_keyboardOf(tester, key)), isTrue,
            reason: '${screen.id} : $key doit ouvrir le clavier numérique');
      }
    }, skip: !a11yFakeApi);
  }

  testWidgets(
      'cas qui doit échouer : un champ de nom n\'est PAS au clavier numérique',
      (tester) async {
    final name = a11yScreens.firstWhere((s) => s.id == 'Nom (1re connexion)');
    await pumpA11y(tester, name, scale: 1.0, mode: ThemeMode.dark);
    expect(
        _isNumeric(_keyboardOf(tester, const ValueKey('name-field'))), isFalse);
  }, skip: !a11yFakeApi);
}
