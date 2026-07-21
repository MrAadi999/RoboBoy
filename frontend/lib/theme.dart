import 'package:flutter/material.dart';

class AadiTheme {
  // Brand Colors
  static const Color primarySaffron = Color(0xFFFF7A00); // Warm energetic Indian Saffron
  static const Color secondaryCyan = Color(0xFF00E5FF);   // Tech Cyan
  
  // Hacker Terminal Palette (Dark Mode)
  static const Color hackerBg = Color(0xFF000000);         // Pure Obsidian Black
  static const Color hackerCard = Color(0xFF080D1A);       // Very Deep Slate / Tech Console
  static const Color hackerGreen = Color(0xFF39FF14);      // Neon Matrix/Laser Green
  static const Color hackerCyan = Color(0xFF00F0FF);       // Cyber Cyan Glow
  static const Color hackerText = Color(0xFF39FF14);       // Terminal output text
  static const Color hackerTextSecondary = Color(0xFF00C0AA); // Dimmed Teal/Green
  static const Color hackerAmber = Color(0xFFFFB300);      // Decryption Alert/Warning

  // Cyber SOC Palette (Light Mode)
  static const Color lightBg = Color(0xFFF1F5F9);         // Cool Slate White
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF0F172A);        // Slate 900
  static const Color lightTextSecondary = Color(0xFF475569); // Slate 600

  // Theme Data Builder
  static ThemeData getDarkTheme() {
    return ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: const ColorScheme.dark(
        primary: hackerGreen,
        secondary: hackerCyan,
        background: hackerBg,
        surface: hackerCard,
        error: Colors.redAccent,
      ),
      scaffoldBackgroundColor: hackerBg,
      cardColor: hackerCard,
      dividerColor: hackerGreen.withOpacity(0.2),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: hackerGreen, 
          fontWeight: FontWeight.bold, 
          fontSize: 24,
          fontFamily: 'monospace',
          shadows: [
            Shadow(color: hackerGreen, blurRadius: 8),
          ]
        ),
        titleMedium: TextStyle(
          color: hackerGreen, 
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
        bodyLarge: TextStyle(
          color: hackerGreen,
          fontFamily: 'monospace',
        ),
        bodyMedium: TextStyle(
          color: hackerTextSecondary,
          fontFamily: 'monospace',
        ),
        labelLarge: TextStyle(
          color: hackerCyan,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: hackerBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: hackerGreen),
        titleTextStyle: TextStyle(
          color: hackerGreen, 
          fontSize: 20, 
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          shadows: [
            Shadow(color: hackerGreen, blurRadius: 5),
          ]
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: hackerCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: hackerGreen.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: hackerGreen.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: hackerCyan, width: 2),
        ),
        labelStyle: const TextStyle(color: hackerTextSecondary, fontFamily: 'monospace'),
        hintStyle: TextStyle(color: hackerTextSecondary.withOpacity(0.6), fontFamily: 'monospace'),
      ),
      iconTheme: const IconThemeData(color: hackerGreen),
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
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primarySaffron, width: 2),
        ),
        hintStyle: const TextStyle(color: lightTextSecondary),
      ),
    );
  }
}
