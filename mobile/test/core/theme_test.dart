import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/app.dart';
import 'package:netbuis/core/theme/app_colors.dart';
import 'package:netbuis/core/theme/app_theme.dart';
import 'package:netbuis/core/widgets/netbuis_logo.dart';

void main() {
  test('thème sombre : jetons de docs/design/README.md', () {
    final c = AppTheme.dark.extension<AppColors>()!;
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.dark.scaffoldBackgroundColor, const Color(0xFF0D0D0F));
    expect(c.card, const Color(0xFF1B1B1E));
    expect(c.border, const Color(0xFF2A2A2E));
    expect(c.textPrimary, const Color(0xFFFFFFFF));
    expect(c.textSecondary, const Color(0xFF9A9A9E));
    expect(c.accentText, const Color(0xFFF2942E));
    expect(AppTheme.dark.colorScheme.primary, const Color(0xFFF2942E));
    expect(AppTheme.dark.colorScheme.onPrimary, const Color(0xFF1A1200));
  });

  test('thème clair : fond #F7F7F8 et contraste D-20', () {
    final c = AppTheme.light.extension<AppColors>()!;
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.light.scaffoldBackgroundColor, const Color(0xFFF7F7F8));
    expect(c.card, const Color(0xFFFFFFFF));
    expect(c.accentText, const Color(0xFFA85A00));
    expect(c.textSecondary, const Color(0xFF6B6B70));
    // Les boutons gardent l'accent orange et le texte foncé.
    expect(AppTheme.light.colorScheme.primary, const Color(0xFFF2942E));
    expect(AppTheme.light.colorScheme.onPrimary, const Color(0xFF1A1200));
    // L'orange ne doit jamais servir de texte en clair (2,2:1 seulement).
    expect(c.accentText, isNot(const Color(0xFFF2942E)));
  });

  test('boutons, champs et cartes : rayons et graisse de la maquette Main', () {
    for (final theme in [AppTheme.dark, AppTheme.light]) {
      final button = theme.elevatedButtonTheme.style!;
      final shape = button.shape!.resolve({})! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12));
      expect(button.textStyle!.resolve({})!.fontWeight, FontWeight.w700);
      expect(button.minimumSize!.resolve({})!.height, greaterThanOrEqualTo(48));
      expect(button.backgroundColor!.resolve({}), AppColors.accent);
      expect(button.foregroundColor!.resolve({}), AppColors.onAccent);

      final field = theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
      expect(field.borderRadius, BorderRadius.circular(14));

      final card = theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(card.borderRadius, BorderRadius.circular(16));
    }
  });

  for (final mode in [ThemeMode.dark, ThemeMode.light]) {
    testWidgets('le thème $mode se construit sans erreur', (tester) async {
      await tester.pumpWidget(ProviderScope(child: NetBuisApp(themeMode: mode)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final context = tester.element(find.byType(NetBuisLogo));
      final expected = mode == ThemeMode.dark ? Brightness.dark : Brightness.light;
      expect(Theme.of(context).brightness, expected);
    });
  }

  testWidgets('logo : NET en couleur de texte, BUIS en accent, graisse 800', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const Scaffold(body: NetBuisLogo())),
    );
    final rich = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
    final parts = rich.children!.cast<TextSpan>();
    expect(parts.map((s) => s.text), ['NET', 'BUIS']);
    expect(parts[0].style!.color, AppColors.light.textPrimary);
    expect(parts[1].style!.color, AppColors.light.accentText);
    expect(rich.style!.fontWeight, FontWeight.w800);
  });
}
