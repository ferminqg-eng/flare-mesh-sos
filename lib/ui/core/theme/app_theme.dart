import 'package:flutter/material.dart';

/// Sistema de diseño táctico de alto contraste optimizado para lectura rápida bajo estrés
/// y ahorro energético OLED en emergencias off-grid.
abstract final class AppTheme {
  static const Color backgroundObsidian = Color(0xFF0D1117);
  static const Color surfaceSlate = Color(0xFF161B22);
  static const Color cardBorder = Color(0xFF2D333B);
  static const Color flameRed = Color(0xFFFF3B30);
  static const Color flameAmber = Color(0xFFFF9500);
  static const Color signalCyan = Color(0xFF00D4FF);
  static const Color relayGreen = Color(0xFF2EA043);

  static ThemeData get darkEmergencyTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: flameRed,
      brightness: Brightness.dark,
      surface: surfaceSlate,
      primary: flameRed,
      secondary: flameAmber,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundObsidian,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundObsidian,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surfaceSlate,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: cardBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSlate,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: flameAmber, width: 2),
        ),
      ),
    );
  }
}
