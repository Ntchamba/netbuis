import 'package:flutter/material.dart';

/// Jetons de couleur des maquettes (docs/design/README.md, décision D-20).
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.card,
    required this.border,
    required this.navBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentText,
  });

  /// Accent officiel (fond des boutons), identique dans les deux thèmes.
  static const Color accent = Color(0xFFF2942E);

  /// Texte et icônes posés sur l'accent.
  static const Color onAccent = Color(0xFF1A1200);

  static const AppColors dark = AppColors(
    background: Color(0xFF0D0D0F),
    card: Color(0xFF1B1B1E),
    border: Color(0xFF2A2A2E),
    navBackground: Color(0xFF121214),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9A9A9E),
    accentText: accent,
  );

  static const AppColors light = AppColors(
    background: Color(0xFFF7F7F8),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE3E3E7),
    navBackground: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF18181B),
    textSecondary: Color(0xFF6B6B70),
    accentText: Color(0xFFA85A00),
  );

  final Color background;
  final Color card;
  final Color border;
  final Color navBackground;
  final Color textPrimary;
  final Color textSecondary;

  /// Texte et icônes en couleur d'accent (plus foncé en clair pour le contraste, D-20).
  final Color accentText;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith({
    Color? background,
    Color? card,
    Color? border,
    Color? navBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? accentText,
  }) {
    return AppColors(
      background: background ?? this.background,
      card: card ?? this.card,
      border: border ?? this.border,
      navBackground: navBackground ?? this.navBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accentText: accentText ?? this.accentText,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      navBackground: Color.lerp(navBackground, other.navBackground, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
    );
  }
}
