import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Thèmes clair et sombre calés sur la maquette Main.
class AppTheme {
  const AppTheme._();

  static const double buttonRadius = 12;
  static const double fieldRadius = 14;
  static const double cardRadius = 16;

  static final ThemeData dark = _build(Brightness.dark, AppColors.dark);
  static final ThemeData light = _build(Brightness.light, AppColors.light);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      error: brightness == Brightness.dark ? const Color(0xFFE25C4A) : const Color(0xFFD1452F),
      onError: Colors.white,
      surface: c.background,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainer: c.card,
      outline: c.border,
      outlineVariant: c.border,
    );
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius));
    const buttonText = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
    const minButton = Size(48, 48);
    OutlineInputBorder field(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: color),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      textTheme: AppTypography.textTheme(c.textPrimary, c.textSecondary),
      extensions: [c],
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          elevation: 0,
          minimumSize: minButton,
          padding: const EdgeInsets.all(12),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          minimumSize: minButton,
          padding: const EdgeInsets.all(12),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border),
          minimumSize: minButton,
          padding: const EdgeInsets.all(12),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        hintStyle: TextStyle(fontSize: 14, color: c.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: field(c.border),
        enabledBorder: field(c.border),
        focusedBorder: field(c.accentText),
        errorBorder: field(scheme.error),
        focusedErrorBorder: field(scheme.error),
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.navBackground,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? c.accentText : c.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.accentText)
              : TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.textSecondary),
        ),
      ),
    );
  }
}
