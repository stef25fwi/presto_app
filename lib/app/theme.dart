import 'package:flutter/material.dart';

import 'presto_overlay_theme.dart';
import '../constants.dart';

/// Theme singleton — built once, reused across rebuilds.
final ThemeData _prestoThemeSingleton = _buildPrestoThemeData();

ThemeData buildPrestoTheme() => _prestoThemeSingleton;

ThemeData _buildPrestoThemeData() {
  const prestoOrange = Color(0xFFFF6600);
  const prestoBlue = Color(0xFF1A73E8);
  const overlayTheme = PrestoOverlayTheme(
    surfaceColor: Colors.white,
    surfaceTintColor: Colors.white,
    borderColor: Color(0xFFD7DEE8),
    selectionFillColor: Color(0xFFEAF2FF),
    selectionAccentColor: Color(0xFF1A73E8),
    shadowColor: Color(0x140F172A),
    dialogRadius: BorderRadius.all(Radius.circular(24)),
    sheetRadius: BorderRadius.vertical(top: Radius.circular(24)),
    popupRadius: BorderRadius.all(Radius.circular(18)),
  );
  final colorScheme = ColorScheme.fromSeed(
    seedColor: prestoOrange,
    brightness: Brightness.light,
  ).copyWith(
    surface: overlayTheme.surfaceColor,
    surfaceContainerHighest: const Color(0xFFF4F7FB),
    surfaceTint: overlayTheme.surfaceTintColor,
    outlineVariant: overlayTheme.borderColor,
    primary: prestoBlue,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    extensions: const <ThemeExtension<dynamic>>[
      overlayTheme,
    ],
    canvasColor: overlayTheme.surfaceColor,
    cardColor: overlayTheme.surfaceColor,
    dialogBackgroundColor: overlayTheme.surfaceColor,
    splashColor: overlayTheme.selectionFillColor,
    highlightColor: overlayTheme.selectionFillColor,
    hoverColor: const Color(0xFFF1F5F9),
    focusColor: const Color(0xFFE2E8F0),
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
      backgroundColor: overlayTheme.surfaceColor,
      surfaceTintColor: overlayTheme.surfaceTintColor,
      shape: overlayTheme.dialogShape,
      barrierColor: const Color(0x660F172A),
      titleTextStyle: kPrestoSectionTitleStyle.copyWith(
        color: const Color(0xFF111827),
      ),
      contentTextStyle: kPrestoBodyTextStyle.copyWith(
        color: const Color(0xFF111827),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: overlayTheme.surfaceColor,
      modalBackgroundColor: overlayTheme.surfaceColor,
      surfaceTintColor: overlayTheme.surfaceTintColor,
      shape: overlayTheme.sheetShape,
      showDragHandle: true,
      dragHandleColor: const Color(0xFF94A3B8),
      modalBarrierColor: const Color(0x660F172A),
      elevation: 10,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: overlayTheme.surfaceColor,
      surfaceTintColor: overlayTheme.surfaceTintColor,
      shape: overlayTheme.popupShape,
      shadowColor: overlayTheme.shadowColor,
      textStyle: kPrestoBodyTextStyle.copyWith(
        color: const Color(0xFF0F172A),
        fontWeight: FontWeight.w600,
      ),
      menuPadding: const EdgeInsets.symmetric(vertical: 8),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor:
            WidgetStatePropertyAll<Color>(overlayTheme.surfaceColor),
        surfaceTintColor:
            WidgetStatePropertyAll<Color>(overlayTheme.surfaceTintColor),
        shadowColor: WidgetStatePropertyAll<Color>(overlayTheme.shadowColor),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(borderRadius: overlayTheme.popupRadius),
        ),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: overlayTheme.borderColor),
        ),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      tileColor: overlayTheme.surfaceColor,
      selectedColor: overlayTheme.selectionAccentColor,
      selectedTileColor: overlayTheme.selectionFillColor,
      iconColor: const Color(0xFF475569),
      textColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: overlayTheme.popupRadius,
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
