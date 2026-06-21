import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const ink = Color(0xFF0F172A);
const card = Color(0xFF1E293B);
const card2 = Color(0xFF334155);
const muted = Color(0xFF94A3B8);
const primary = Color(0xFF2563EB);
const primary2 = Color(0xFF1D4ED8);
const success = Color(0xFF10B981);
const warning = Color(0xFFF59E0B);
const danger = Color(0xFFEF4444);
const border = Color(0xFF334155);

ThemeData buildAdminTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.dark,
    surface: ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: ink,
    textTheme: GoogleFonts.hindTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ).apply(bodyColor: const Color(0xFFE2E8F0), displayColor: Colors.white),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: card,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: GoogleFonts.baloo2(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.baloo2(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      labelStyle: GoogleFonts.hind(color: muted),
      hintStyle: GoogleFonts.hind(color: muted),
    ),
    dividerColor: border,
  );
}