// T120 : chaque écran (docs/spec/ACCESSIBILITE.md + écrans sans maquette) à 360 px, en clair et
// en sombre, avec la police du téléphone à 100 %, 130 % (et 200 % pour les écrans critiques).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a11y_harness.dart';
import 'screens.dart';

void main() {
  for (final screen in a11yScreens) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final theme = mode == ThemeMode.light ? 'clair' : 'sombre';
      final scales = [1.0, 1.3, if (screen.critical) 2.0];
      for (final scale in scales) {
        testWidgets(
            '${screen.id} · $theme · police ×$scale : pas de débordement, pas de défilement horizontal',
            (tester) async {
          await pumpA11y(tester, screen, scale: scale, mode: mode);
          expectShown(screen);
          await checkEveryPage(tester, () async {
            expectNoRenderError(tester, screen.id);
            expectNoHorizontalScroll(tester, screen.id);
            expectInsideWidth(tester, screen.id);
          });
        }, skip: !a11yFakeApi);
      }
      // Deux hauteurs : 780 px (l'écran réel) et 4000 px (« tout déplié » : tout est construit et
      // rien n'est coupé par un bord, sinon la plateforme juge « trop petit » un élément seulement
      // à moitié visible).
      for (final height in [780.0, 4000.0]) {
        testWidgets(
            '${screen.id} · $theme · ${height.round()} px : cibles ≥ 48 dp, étiquettes${height > 1000 ? ', contraste ≥ 4,5:1' : ''}',
            (tester) async {
          final handle = tester.ensureSemantics();
          await pumpA11y(tester, screen,
              scale: 1.0, mode: mode, height: height);
          expectShown(screen);
          // Contraste : seulement « tout déplié » ; à 780 px, un champ à moitié caché sous le bouton
          // collant est mesuré avec les pixels orange du bouton (faux positif de la plateforme).
          final problems =
              await guidelineProblems(tester, contrast: height > 1000);
          expect(problems, isEmpty,
              reason: '${screen.id} ($theme, $height px)');
          handle.dispose();
        }, skip: !a11yFakeApi);
      }
    }
  }
}
