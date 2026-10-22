// T120 : contraste calculé (WCAG 2) des paires de couleurs des jetons, en clair et en sombre.
// Complète `textContrastGuideline`, qui ne voit pas les textes cachés derrière une image
// et ne juge pas les icônes.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/theme/app_colors.dart';
import 'package:netbuis/core/theme/app_theme.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

/// Rapport de contraste WCAG entre deux couleurs opaques.
double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('rapport de contraste : noir/blanc = 21, deux gris identiques = 1', () {
    expect(contrast(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrast(const Color(0xFF777777), const Color(0xFF777777)),
        closeTo(1, 0.001));
  });

  test(
      'cas qui doit échouer : l\'orange d\'accent en texte sur le fond clair est sous 4,5:1',
      () {
    expect(
        contrast(AppColors.accent, AppColors.light.background), lessThan(4.5));
  });

  for (final entry
      in {'clair': AppTheme.light, 'sombre': AppTheme.dark}.entries) {
    final c = entry.value.extension<AppColors>()!;
    final scheme = entry.value.colorScheme;
    final pairs = <String, (Color, Color)>{
      'texte / fond': (c.textPrimary, c.background),
      'texte / carte': (c.textPrimary, c.card),
      'texte secondaire / fond': (c.textSecondary, c.background),
      'texte secondaire / carte': (c.textSecondary, c.card),
      'texte d\'accent / fond': (c.accentText, c.background),
      'texte d\'accent / carte': (c.accentText, c.card),
      'texte de la barre de navigation / fond de la barre': (
        c.textSecondary,
        c.navBackground
      ),
      'accent de la barre de navigation / fond de la barre': (
        c.accentText,
        c.navBackground
      ),
      'bouton : texte foncé / fond orange': (
        AppColors.onAccent,
        AppColors.accent
      ),
      'erreur / fond': (scheme.error, c.background),
      'erreur / carte': (scheme.error, c.card),
    };
    for (final p in pairs.entries) {
      test('thème ${entry.key} : ${p.key} ≥ 4,5:1', () {
        expect(contrast(p.value.$1, p.value.$2), greaterThanOrEqualTo(4.5),
            reason: p.key);
      });
    }
  }

  // Couleurs écrites directement dans les écrans (hors jetons) : texte / fond réellement posés.
  final onWhite = AppColors.light.card, onDarkCard = AppColors.dark.card;
  final extra = <String, (Color, Color)>{
    'clair : « Actif » (vert) / carte': (const Color(0xFF1E7B4F), onWhite),
    'sombre : « Actif » (vert) / carte': (const Color(0xFF4CC38A), onDarkCard),
    'clair : badge WhatsApp (vert / vert pâle)': (
      const Color(0xFF1A7A34),
      const Color(0xFFE3F5E7)
    ),
    'sombre : badge WhatsApp (vert / vert sombre)': (
      const Color(0xFF5FBE7A),
      const Color(0xFF1E2E22)
    ),
    'clair : badge Appel (accent / pêche)': (
      AppColors.light.accentText,
      const Color(0xFFFEF3E2)
    ),
    'sombre : badge Appel (accent / brun)': (
      AppColors.dark.accentText,
      const Color(0xFF262620)
    ),
    'clair : étiquette produit': (
      AppColors.light.accentText,
      const Color(0xFFFEF3E2)
    ),
    'sombre : étiquette produit': (AppColors.accent, const Color(0xFF262620)),
    'clair : texte de la carte schématique': (
      const Color(0xFF4A4A50),
      const Color(0xFFEFEFF2)
    ),
    'sombre : texte de la carte schématique': (
      const Color(0xFFC8C8CC),
      const Color(0xFF15151A)
    ),
    'clair : texte / encart d\'abonnement': (
      AppColors.light.textPrimary,
      const Color(0xFFFFF6E8)
    ),
    'clair : texte secondaire / encart d\'abonnement': (
      AppColors.light.textSecondary,
      const Color(0xFFFFF6E8)
    ),
    'sombre : texte / encart d\'abonnement': (
      AppColors.dark.textPrimary,
      const Color(0xFF241D10)
    ),
    'sombre : texte secondaire / encart d\'abonnement': (
      AppColors.dark.textSecondary,
      const Color(0xFF241D10)
    ),
    'ligne Orange : texte foncé / fond': (
      const Color(0xFF1A1200),
      const Color(0xFFFF7900)
    ),
    'ligne MTN : texte foncé / fond': (
      const Color(0xFF1A1200),
      const Color(0xFFFFCC00)
    ),
  };
  for (final p in extra.entries) {
    test('hors jetons, ${p.key} ≥ 4,5:1', () {
      expect(contrast(p.value.$1, p.value.$2), greaterThanOrEqualTo(4.5),
          reason: p.key);
    });
  }

  test(
      'D-20 : en clair, l\'accent de texte est #A85A00 (≥ 4,5:1) et le secondaire #6B6B70',
      () {
    expect(AppColors.light.accentText, const Color(0xFFA85A00));
    expect(AppColors.light.textSecondary, const Color(0xFF6B6B70));
  });
}
