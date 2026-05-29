import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// JEDI — Modern Light Tech Design System
/// A clean, accessible, and high-contrast theme for cybersecurity ops.
class JediTheme {
  JediTheme._();

  // ─── Color Palette (Light Tech) ───────────────────────────────────────────
  static const Color background    = Color(0xFFF4F4F5); // Zink 100
  static const Color surface       = Color(0xFFFFFFFF); // Pure White
  static const Color surfaceBorder = Color(0xFFE4E4E7); // Zink 200
  
  static const Color primary       = Color(0xFF2563EB); // Tech Blue
  static const Color critical      = Color(0xFFEF4444); // Alert Red
  static const Color medium        = Color(0xFFF59E0B); // Warning Amber
  static const Color safe          = Color(0xFF10B981); // Emerald Green
  
  static const Color textPrimary   = Color(0xFF09090B); // Zink 950
  static const Color textSecondary = Color(0xFF71717A); // Zink 500

  // ─── Derived / Utility ────────────────────────────────────────────────────
  static const Color criticalDim   = Color(0x1AEF4444); // 10% alpha critical
  static const Color safeDim       = Color(0x1A10B981); // 10% alpha safe
  static const Color mediumDim     = Color(0x1AF59E0B); // 10% alpha medium
  static const Color primaryDim    = Color(0x1A2563EB); // 10% alpha primary

  // ─── Spacing ──────────────────────────────────────────────────────────────
  static const double spaceXS  = 4.0;
  static const double spaceS   = 8.0;
  static const double spaceM   = 16.0;
  static const double spaceL   = 24.0;
  static const double spaceXL  = 32.0;
  static const double spaceXXL = 48.0;

  // ─── Border Radius ────────────────────────────────────────────────────────
  static const double radiusS  = 6.0;
  static const double radiusM  = 12.0;
  static const double radiusL  = 16.0;

  // ─── Sizes ────────────────────────────────────────────────────────────────
  static const double headerHeight      = 68.0;
  static const double leftPaneWidth     = 300.0;
  static const double mobileBreakpoint  = 800.0;

  // ─── Shadows ──────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF09090B).withAlpha(10), // Very subtle shadow
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get hoverShadow => [
    BoxShadow(
      color: const Color(0xFF09090B).withAlpha(15),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  // ─── Text Styles ──────────────────────────────────────────────────────────

  /// JetBrains Mono — for numbers, code snippets, and logs
  static TextStyle monoStyle({
    double fontSize = 14,
    Color color = textPrimary,
    FontWeight fontWeight = FontWeight.normal,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
      );

  /// Inter — highly legible sans-serif for UI, headings, and body
  static TextStyle bodyStyle({
    double fontSize = 14,
    Color color = textPrimary,
    FontWeight fontWeight = FontWeight.normal,
  }) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        letterSpacing: -0.2, // Tighter modern letter spacing
      );

  // ─── MaterialApp ThemeData ────────────────────────────────────────────────

  /// Returns the global [ThemeData] for the JEDI app.
  static ThemeData get themeData => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.light(
          surface: surface,
          primary: primary,
          secondary: medium,
          error: critical,
          onSurface: textPrimary,
          onPrimary: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(
          const TextTheme(
            bodyMedium: TextStyle(color: textPrimary),
            bodySmall: TextStyle(color: textSecondary),
          ),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
            side: const BorderSide(color: surfaceBorder, width: 1),
          ),
        ),
        dividerColor: surfaceBorder,
        useMaterial3: true,
      );

  // ─── Health Score Color Helper ────────────────────────────────────────────

  /// Returns the appropriate status color for a given [healthScore] (0.0–1.0).
  static Color healthColor(double healthScore) {
    if (healthScore >= 0.8) return safe;
    if (healthScore >= 0.5) return medium;
    return critical;
  }

  /// Returns the appropriate status color for a threat level string.
  static Color threatLevelColor(String threatLevel) {
    switch (threatLevel.toLowerCase()) {
      case 'critical':
        return critical;
      case 'medium':
        return medium;
      default:
        return safe;
    }
  }
}
