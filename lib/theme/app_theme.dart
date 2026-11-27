import 'package:flutter/material.dart';

class AppTheme {
  // NEON XO original game colors
  static const Color background = Color(0xFF0B0B2B);
  static const Color purple = Color(0xFF7B2FF7);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonPink = Color(0xFFFF2BD6);
  static const Color neonYellow = Color(0xFFFFD600);

  // Admin panel surfaces
  static const Color surface = Color(0xFF171F35);
  static const Color cardSurface = Color(0xFF141A32);

  // Backward-compatible names
  static const Color primary = purple;
  static const Color secondary = neonCyan;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,

      colorScheme: const ColorScheme.dark(
        primary: purple,
        secondary: neonCyan,
        surface: surface,
        error: Colors.redAccent,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: neonCyan,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(
          color: neonCyan,
        ),
      ),

      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 4,
        shadowColor: purple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: purple.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(
          color: Colors.white38,
        ),
        labelStyle: const TextStyle(
          color: neonCyan,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: purple.withValues(alpha: 0.4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: neonCyan,
            width: 1.5,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: purple,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: neonCyan,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.12),
      ),

      iconTheme: const IconThemeData(
        color: neonCyan,
      ),
    );
  }
}