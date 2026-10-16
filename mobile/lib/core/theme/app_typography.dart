import 'package:flutter/material.dart';

/// Tailles et graisses : titres 22 sp gras, corps 16 sp, légendes 14 sp.
class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: primary),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: primary),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primary),
      bodyLarge: TextStyle(fontSize: 16, color: primary),
      bodyMedium: TextStyle(fontSize: 14, color: primary),
      bodySmall: TextStyle(fontSize: 13, color: secondary),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    );
  }
}
