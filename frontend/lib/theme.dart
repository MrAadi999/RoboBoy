import 'package:flutter/material.dart';

class AadiTheme {
  // Brand Colors
  static const Color primarySaffron = Color(0xFFFF7A00); // Warm energetic Indian Saffron
  static const Color secondaryCyan = Color(0xFF00E5FF);   // Tech Cyan
  
  // Dark Palette
  static const Color darkBg = Color(0xFF0C101B);          // Obsidian Night
  static const Color darkCard = Color(0xFF171D2F);        // Deep Slate
  static const Color darkText = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);

  // Light Palette
  static const Color lightBg = Color(0xFFF6F8FB);         // Soft cream-white
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF1F2937);
  static const Color lightTextSecondary = Color(0xFF6B7280);

  // Theme Data Builder
  static ThemeData getDarkTheme() {
    return ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: const ColorScheme.dark(
        primary: primarySaffron,
        secondary: secondaryCyan,
        background: darkBg,
        surface: darkCard,
      ),
      scaffoldBackgroundColor: darkBg,
      cardColor: darkCard,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: darkText, fontWeight: FontWeight.bold, fontSize: 24),
        titleMedium: TextStyle(color: darkText, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: darkText),
        bodyMedium: TextStyle(color: darkTextSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        iconTheme: IconThemeData(color: darkText),
        titleTextStyle: TextStyle(color: darkText, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2E374E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primarySaffron, width: 2),
        ),
        hintStyle: const TextStyle(color: darkTextSecondary),
      ),
    );
  }

  static ThemeData getLightTheme() {
    return ThemeData.light(useMaterial3: true).copyWith(
      colorScheme: const ColorScheme.light(
        primary: primarySaffron,
        secondary: secondaryCyan,
        background: lightBg,
        surface: lightCard,
      ),
      scaffoldBackgroundColor: lightBg,
      cardColor: lightCard,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: lightText, fontWeight: FontWeight.bold, fontSize: 24),
        titleMedium: TextStyle(color: lightText, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: lightText),
        bodyMedium: TextStyle(color: lightTextSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        elevation: 0,
        iconTheme: IconThemeData(color: lightText),
        titleTextStyle: TextStyle(color: lightText, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primarySaffron, width: 2),
        ),
        hintStyle: const TextStyle(color: lightTextSecondary),
      ),
    );
  }
}
