import 'package:flutter/material.dart';

class NeoColors {
  static const Color bg = Color(0xFFFFF4E0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF0D0D0D);
  static const Color primary = Color(0xFFFFDE59);
  static const Color secondary = Color(0xFFFF5C8A);
  static const Color tertiary = Color(0xFFB28DFF);
  static const Color info = Color(0xFF5CA8FF);
  static const Color success = Color(0xFF5CE08A);
  static const Color danger = Color(0xFFFF4D4D);
  static const Color warning = Color(0xFFFFDE59);
  static const Color muted = Color(0xFFD9D2C3);
}

class NeoTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: NeoColors.bg,
      colorScheme: ColorScheme.light(
        primary: NeoColors.primary,
        secondary: NeoColors.secondary,
        surface: NeoColors.surface,
        error: NeoColors.danger,
        onPrimary: NeoColors.ink,
        onSecondary: NeoColors.ink,
        onSurface: NeoColors.ink,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: NeoColors.ink,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: NeoColors.ink,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Hanken Grotesk',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: NeoColors.ink,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Space Mono',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: NeoColors.ink,
        ),
      ),
    );
  }
}
