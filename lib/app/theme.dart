import 'package:flutter/material.dart';

import '../constants.dart';

/// Theme singleton — built once, reused across rebuilds.
final ThemeData _prestoThemeSingleton = _buildPrestoThemeData();

ThemeData buildPrestoTheme() => _prestoThemeSingleton;

ThemeData _buildPrestoThemeData() {
  const prestoOrange = Color(0xFFFF6600);
  const prestoBlue = Color(0xFF1A73E8);

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: prestoOrange,
      brightness: Brightness.light,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      foregroundColor: Colors.white,
      titleTextStyle: kPrestoAppBarTitleStyle.copyWith(color: Colors.white),
      toolbarTextStyle: kPrestoBodyTextStyle.copyWith(color: Colors.white),
    ),
    textTheme: const TextTheme(
      titleLarge: kPrestoSectionTitleStyle,
      titleMedium: kPrestoCardTitleStyle,
      bodyMedium: kPrestoBodyTextStyle,
      bodySmall: kPrestoMetaTextStyle,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      titleTextStyle: kPrestoSectionTitleStyle.copyWith(
        color: const Color(0xFF111827),
      ),
      contentTextStyle: kPrestoBodyTextStyle.copyWith(
        color: const Color(0xFF111827),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
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
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: kPrestoBodyTextStyle.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        textStyle: kPrestoBodyTextStyle.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: kPrestoBodyTextStyle.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
  );
}
