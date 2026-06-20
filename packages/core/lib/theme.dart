import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Brand palette (DESIGN.md Section 1)
const blue      = Color(0xFF1D4ED8);
const blueDark  = Color(0xFF0B3A7A);
const blueDeep  = Color(0xFF0B2447);
const cyan      = Color(0xFF06B6D4);
const green     = Color(0xFF16A34A);
const greenBright = Color(0xFF22C55E);
const red       = Color(0xFFE5484D);
const gold      = Color(0xFFFFB020);
const ink       = Color(0xFF0B2447);
const muted     = Color(0xFF6B86A8);
const bg        = Color(0xFFEFF5FF);
const card      = Color(0xFFFFFFFF);
const line      = Color(0xFFDCE7F7);
const tintBlue  = Color(0xFFDCE9FF);
const tintGreen = Color(0xFFE4FBEF);
const tintCyan  = Color(0xFFE6F4FF);
const tintGold  = Color(0xFFFFF1D6);

// Blue-tinted shadow used across cards and buttons
BoxShadow blueShadow({double opacity = 0.25, double blurRadius = 20}) =>
    BoxShadow(color: blue.withOpacity(opacity), blurRadius: blurRadius, offset: const Offset(0, 8));

ThemeData rickboTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: blue,
      primary: blue,
      secondary: cyan,
      error: red,
      surface: card,
    ),
    scaffoldBackgroundColor: bg,
    cardColor: card,
    dividerColor: line,
  );

  return base.copyWith(
    textTheme: GoogleFonts.hindTextTheme(base.textTheme).copyWith(
      // Display XL 34/800 — greeting "कहाँ चलें?"
      displayLarge: GoogleFonts.baloo2(fontSize: 34, fontWeight: FontWeight.w800, color: ink),
      // Display L 24/700 — card titles
      displayMedium: GoogleFonts.baloo2(fontSize: 24, fontWeight: FontWeight.w700, color: ink),
      headlineMedium: GoogleFonts.baloo2(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
      bodyLarge: GoogleFonts.hind(fontSize: 18, fontWeight: FontWeight.w600, color: ink),
      bodyMedium: GoogleFonts.hind(fontSize: 16, fontWeight: FontWeight.w500, color: ink),
      labelSmall: GoogleFonts.hind(fontSize: 13, fontWeight: FontWeight.w600, color: muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: line),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: card,
      foregroundColor: ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.baloo2(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: blue, width: 2),
      ),
    ),
  );
}
