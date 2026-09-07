import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFFF4EEDD);
  static const card = Color(0xFFFFFDF8);
  static const border = Color(0xFFEDE3CC);
  static const ink = Color(0xFF2A2418);
  static const inkMuted = Color(0xFFA89A82);
  static const inkSoft = Color(0xFF7A6A52);
  static const green = Color(0xFF1B4332);
  static const greenLight = Color(0xFF2D6A4F);
  static const orange = Color(0xFFB3441F);

  static const mtn = Color(0xFFFFCC00);
  static const moov = Color(0xFF0057B8);
  static const celtiis = Color(0xFF323D63);
}

ThemeData buildAppTheme() {
  final base = GoogleFonts.outfitTextTheme();
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green,
      primary: AppColors.green,
      surface: AppColors.card,
    ),
    textTheme: base.copyWith(
      bodyLarge: base.bodyLarge?.copyWith(color: AppColors.ink),
      bodyMedium: base.bodyMedium?.copyWith(color: AppColors.inkSoft),
      titleLarge: base.titleLarge?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.green,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      shadowColor: AppColors.ink.withValues(alpha: 0.06),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.green, width: 1.5),
      ),
      hintStyle: GoogleFonts.outfit(color: AppColors.inkMuted, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.green,
        side: const BorderSide(color: AppColors.green),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.outfit(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.green,
        textStyle: GoogleFonts.outfit(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.green.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
