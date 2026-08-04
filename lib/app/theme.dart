import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import 'presto_design_tokens.dart';
import 'presto_overlay_theme.dart';

/// Theme singleton — built once, reused across rebuilds.
final ThemeData _prestoThemeSingleton = _buildPrestoThemeData();

ThemeData buildPrestoTheme() => _prestoThemeSingleton;

ThemeData _buildPrestoThemeData() {
  const overlayTheme = PrestoOverlayTheme(
    surfaceColor: PrestoColors.surface,
    surfaceTintColor: PrestoColors.surface,
    borderColor: PrestoColors.border,
    selectionFillColor: PrestoColors.surfaceSelected,
    selectionAccentColor: PrestoColors.brandBlue,
    shadowColor: PrestoColors.shadow,
    dialogRadius: BorderRadius.all(Radius.circular(PrestoRadii.xl)),
    sheetRadius: BorderRadius.vertical(
      top: Radius.circular(PrestoRadii.xl),
    ),
    popupRadius: BorderRadius.all(Radius.circular(PrestoRadii.lg)),
  );
  final colorScheme = ColorScheme.fromSeed(
    seedColor: PrestoColors.brandOrange,
    brightness: Brightness.light,
  ).copyWith(
    surface: overlayTheme.surfaceColor,
    surfaceContainerHighest: PrestoColors.surfaceMuted,
    surfaceTint: overlayTheme.surfaceTintColor,
    outlineVariant: overlayTheme.borderColor,
    primary: PrestoColors.brandBlue,
    onPrimary: PrestoColors.textOnBlue,
    secondary: PrestoColors.brandOrange,
    onSecondary: PrestoColors.textOnOrange,
    error: PrestoColors.danger,
  );

  const minimumInteractiveSize = WidgetStatePropertyAll<Size>(
    Size(PrestoAccessibility.minTouchTarget, PrestoAccessibility.minTouchTarget),
  );
  const buttonPadding = WidgetStatePropertyAll<EdgeInsetsGeometry>(
    EdgeInsets.symmetric(
      horizontal: PrestoSpacing.md,
      vertical: PrestoSpacing.sm,
    ),
  );

  // Le seul indicateur de focus opposable est un anneau contrasté : la teinte
  // de survol par défaut ne dépasse pas 1,2:1 sur fond clair et resterait
  // invisible au clavier.
  const focusRingSide = BorderSide(
    color: PrestoColors.focusRing,
    width: PrestoAccessibility.focusRingWidth,
  );
  final focusRing = WidgetStateProperty.resolveWith<BorderSide?>(
    (states) => states.contains(WidgetState.focused) ? focusRingSide : null,
  );
  // Le bouton contourné conserve sa bordure au repos : renvoyer `null` la
  // supprimerait, la valeur du thème primant sur celle du composant.
  final outlinedFocusRing = WidgetStateProperty.resolveWith<BorderSide?>(
    (states) => states.contains(WidgetState.focused)
        ? focusRingSide
        : const BorderSide(color: PrestoColors.border),
  );

  return ThemeData(
    fontFamily: 'Inter',
    useMaterial3: true,
    colorScheme: colorScheme,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    extensions: const <ThemeExtension<dynamic>>[
      overlayTheme,
    ],
    canvasColor: overlayTheme.surfaceColor,
    cardColor: overlayTheme.surfaceColor,
    splashColor: overlayTheme.selectionFillColor,
    highlightColor: overlayTheme.selectionFillColor,
    hoverColor: PrestoColors.hover,
    focusColor: PrestoColors.focus,
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: PrestoColors.brandBlue,
      foregroundColor: PrestoColors.textOnBlue,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: PrestoColors.brandBlue,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: PrestoColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      titleTextStyle: kPrestoAppBarTitleStyle.copyWith(
        color: PrestoColors.textOnBlue,
      ),
      toolbarTextStyle: kPrestoBodyTextStyle.copyWith(
        color: PrestoColors.textOnBlue,
      ),
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
        color: PrestoColors.textPrimary,
      ),
      contentTextStyle: kPrestoBodyTextStyle.copyWith(
        color: PrestoColors.textPrimary,
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
        color: PrestoColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      menuPadding: const EdgeInsets.symmetric(vertical: PrestoSpacing.xs),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(
          overlayTheme.surfaceColor,
        ),
        surfaceTintColor: WidgetStatePropertyAll<Color>(
          overlayTheme.surfaceTintColor,
        ),
        shadowColor: WidgetStatePropertyAll<Color>(overlayTheme.shadowColor),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(borderRadius: overlayTheme.popupRadius),
        ),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: overlayTheme.borderColor),
        ),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(vertical: PrestoSpacing.xs),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      minTileHeight: PrestoAccessibility.minTouchTarget,
      tileColor: overlayTheme.surfaceColor,
      selectedColor: overlayTheme.selectionAccentColor,
      selectedTileColor: overlayTheme.selectionFillColor,
      iconColor: PrestoColors.textSecondary,
      textColor: PrestoColors.textPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: overlayTheme.popupRadius,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFFF2F3F5),
      contentTextStyle: const TextStyle(
        color: Color(0xFF1A202C),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PrestoRadii.md),
      ),
    ),
    scaffoldBackgroundColor: PrestoColors.scaffold,
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PrestoRadii.md),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PrestoRadii.md),
        borderSide: const BorderSide(color: Colors.black26),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PrestoRadii.md),
        borderSide: focusRingSide,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: PrestoSpacing.lg,
        vertical: PrestoSpacing.md,
      ),
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimumInteractiveSize,
        side: focusRing,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimumInteractiveSize,
        padding: buttonPadding,
        side: focusRing,
        textStyle: WidgetStatePropertyAll<TextStyle>(
          kPrestoBodyTextStyle.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimumInteractiveSize,
        padding: buttonPadding,
        side: focusRing,
        textStyle: WidgetStatePropertyAll<TextStyle>(
          kPrestoBodyTextStyle.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimumInteractiveSize,
        padding: buttonPadding,
        side: focusRing,
        textStyle: WidgetStatePropertyAll<TextStyle>(
          kPrestoBodyTextStyle.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimumInteractiveSize,
        padding: buttonPadding,
        side: outlinedFocusRing,
        textStyle: WidgetStatePropertyAll<TextStyle>(
          kPrestoBodyTextStyle.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}
