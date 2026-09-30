// WastePay Nigeria — App Theme
import 'package:flutter/material.dart';

class WPColors {
  static const green900 = Color(0xFF1B5E20);
  static const green700 = Color(0xFF2E7D32);
  static const green600 = Color(0xFF388E3C);
  static const green500 = Color(0xFF27AE60);
  static const green200 = Color(0xFFA5D6A7);
  static const green50  = Color(0xFFE8F5E9);

  static const gold     = Color(0xFFE8A020);
  static const goldLight= Color(0xFFFDE68A);
  static const terracotta = Color(0xFFC0392B);
  static const navy     = Color(0xFF0D1B2A);

  static const textPrimary   = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF555555);
  static const textMuted     = Color(0xFF999999);
  static const surface       = Color(0xFFF4F9F4);
  static const white         = Color(0xFFFFFFFF);
}

class WastePayTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: WPColors.green500,
      primary: WPColors.green500,
      secondary: WPColors.gold,
      surface: WPColors.white,
    ),
    scaffoldBackgroundColor: WPColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: WPColors.white,
      foregroundColor: WPColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: WPColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: WPColors.green500,
        foregroundColor: WPColors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: WPColors.green500,
        side: const BorderSide(color: WPColors.green500),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WPColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: WPColors.green500, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: WPColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFEEEEEE)),
      ),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: WPColors.green500,
      brightness: Brightness.dark,
      primary: WPColors.green500,
      secondary: WPColors.gold,
      surface: const Color(0xFF1A2E1A),
    ),
    scaffoldBackgroundColor: WPColors.navy,
  );
}
