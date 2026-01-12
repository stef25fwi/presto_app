import 'package:flutter/material.dart';

ThemeData buildPrestoTheme() {
  const prestoOrange = Color(0xFFFF6600);
  const prestoBlue = Color(0xFF1A73E8);

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: prestoOrange,
      brightness: Brightness.light,
    ),
    snackBarTheme: SnackBarThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    scaffoldBackgroundColor: const Color(0xFFFDF4EC),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.black26),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: prestoBlue, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
