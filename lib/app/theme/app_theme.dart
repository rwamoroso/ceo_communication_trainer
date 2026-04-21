import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _ink = Color(0xFF0E1B2A);
  static const _canvas = Color(0xFFF4EFE6);
  static const _surface = Color(0xFFFFFBF5);
  static const _accent = Color(0xFF0F766E);
  static const _warm = Color(0xFFC46A2C);
  static const _muted = Color(0xFF5A6573);

  static ThemeData build() {
    final textTheme = GoogleFonts.manropeTextTheme().copyWith(
      headlineLarge: GoogleFonts.dmSerifDisplay(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: _ink,
      ),
      headlineMedium: GoogleFonts.dmSerifDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        color: _ink,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: _ink,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: _ink,
      ),
      bodyLarge: GoogleFonts.manrope(fontSize: 16, height: 1.45, color: _ink),
      bodyMedium: GoogleFonts.manrope(fontSize: 14, height: 1.5, color: _ink),
      bodySmall: GoogleFonts.manrope(fontSize: 12, height: 1.4, color: _muted),
    );

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: Brightness.light,
          primary: _accent,
          secondary: _warm,
          surface: _surface,
        ).copyWith(
          onSurface: _ink,
          onPrimary: Colors.white,
          tertiary: const Color(0xFF88BDB7),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _canvas,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.78),
        hintStyle: textTheme.bodyMedium?.copyWith(color: _muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surface,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.all(
          textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        side: BorderSide.none,
        backgroundColor: const Color(0xFFE6E3DA),
        selectedColor: colorScheme.primary.withValues(alpha: 0.14),
        labelStyle: textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _ink,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: textTheme.titleMedium?.copyWith(color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: _ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
    );
  }
}
