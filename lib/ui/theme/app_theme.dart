import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The LiquidGlass app theme — deep dark base so glass effects pop.
class AppTheme {
  AppTheme._();

  // ── Brand colours ──
  static const Color primaryAccent = Color(0xFF7EB8FF); // Cool glass blue
  static const Color secondaryAccent = Color(0xFF9EE4D0); // Mint glass green
  static const Color surfaceBase = Color(0xFF0A0A0F); // Near-black canvas
  static const Color surfaceElevated = Color(0xFF14141C);
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF9898A8);
  static const Color textTertiary = Color(0xFF5C5C70);
  static const Color errorRed = Color(0xFFFF6B6B);
  static const Color shimmer = Color(0x33FFFFFF);

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: surfaceBase,
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        secondary: secondaryAccent,
        surface: surfaceBase,
        error: errorRed,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.5),
        headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: -0.3),
        headlineSmall: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary),
        titleLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary),
        titleMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textPrimary),
        bodyLarge: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: textPrimary),
        bodyMedium: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: textSecondary),
        bodySmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: textTertiary),
        labelLarge: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: primaryAccent,
            letterSpacing: 0.3),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      iconTheme: const IconThemeData(color: textPrimary, size: 22),
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.06),
        thickness: 0.5,
      ),
      splashColor: Colors.white12,
      highlightColor: Colors.white10,
    );
  }
}
