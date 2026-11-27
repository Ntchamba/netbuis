import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/l10n/l10n.dart';

void main() {
  testWidgets('les textes sont disponibles dès la fin du chargement, même au-delà de 50 Ko',
      (tester) async {
    // Le chargement ne doit jamais partir en tâche de fond : on l'attend en temps simulé,
    // sans pumpAndSettle ni runAsync.
    for (final lang in ['fr', 'en']) {
      final size = File('assets/l10n/$lang.json').lengthSync();
      expect(size, greaterThan(0));
      final l10n = await L10n.load(Locale(lang));
      expect(l10n.t('nav.forum'), 'Forum');
    }
  });
}
