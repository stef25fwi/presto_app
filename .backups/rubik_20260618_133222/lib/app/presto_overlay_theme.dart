import 'package:flutter/material.dart';

@immutable
class PrestoOverlayTheme extends ThemeExtension<PrestoOverlayTheme> {
  final Color surfaceColor;
  final Color surfaceTintColor;
  final Color borderColor;
  final Color selectionFillColor;
  final Color selectionAccentColor;
  final Color shadowColor;
  final BorderRadius dialogRadius;
  final BorderRadius sheetRadius;
  final BorderRadius popupRadius;

  const PrestoOverlayTheme({
    required this.surfaceColor,
    required this.surfaceTintColor,
    required this.borderColor,
    required this.selectionFillColor,
    required this.selectionAccentColor,
    required this.shadowColor,
    required this.dialogRadius,
    required this.sheetRadius,
    required this.popupRadius,
  });

  static const fallback = PrestoOverlayTheme(
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

  ShapeBorder get dialogShape => RoundedRectangleBorder(
        borderRadius: dialogRadius,
        side: BorderSide(color: borderColor),
      );

  ShapeBorder get sheetShape => RoundedRectangleBorder(
        borderRadius: sheetRadius,
        side: BorderSide(color: borderColor),
      );

  ShapeBorder get popupShape => RoundedRectangleBorder(
        borderRadius: popupRadius,
        side: BorderSide(color: borderColor),
      );

  @override
  PrestoOverlayTheme copyWith({
    Color? surfaceColor,
    Color? surfaceTintColor,
    Color? borderColor,
    Color? selectionFillColor,
    Color? selectionAccentColor,
    Color? shadowColor,
    BorderRadius? dialogRadius,
    BorderRadius? sheetRadius,
    BorderRadius? popupRadius,
  }) {
    return PrestoOverlayTheme(
      surfaceColor: surfaceColor ?? this.surfaceColor,
      surfaceTintColor: surfaceTintColor ?? this.surfaceTintColor,
      borderColor: borderColor ?? this.borderColor,
      selectionFillColor: selectionFillColor ?? this.selectionFillColor,
      selectionAccentColor: selectionAccentColor ?? this.selectionAccentColor,
      shadowColor: shadowColor ?? this.shadowColor,
      dialogRadius: dialogRadius ?? this.dialogRadius,
      sheetRadius: sheetRadius ?? this.sheetRadius,
      popupRadius: popupRadius ?? this.popupRadius,
    );
  }

  @override
  PrestoOverlayTheme lerp(
    covariant ThemeExtension<PrestoOverlayTheme>? other,
    double t,
  ) {
    if (other is! PrestoOverlayTheme) return this;

    return PrestoOverlayTheme(
      surfaceColor:
          Color.lerp(surfaceColor, other.surfaceColor, t) ?? other.surfaceColor,
      surfaceTintColor:
          Color.lerp(surfaceTintColor, other.surfaceTintColor, t) ??
              other.surfaceTintColor,
      borderColor:
          Color.lerp(borderColor, other.borderColor, t) ?? other.borderColor,
      selectionFillColor:
          Color.lerp(selectionFillColor, other.selectionFillColor, t) ??
              other.selectionFillColor,
      selectionAccentColor:
          Color.lerp(selectionAccentColor, other.selectionAccentColor, t) ??
              other.selectionAccentColor,
      shadowColor:
          Color.lerp(shadowColor, other.shadowColor, t) ?? other.shadowColor,
      dialogRadius: BorderRadius.lerp(dialogRadius, other.dialogRadius, t) ??
          other.dialogRadius,
      sheetRadius: BorderRadius.lerp(sheetRadius, other.sheetRadius, t) ??
          other.sheetRadius,
      popupRadius: BorderRadius.lerp(popupRadius, other.popupRadius, t) ??
          other.popupRadius,
    );
  }
}

extension PrestoOverlayThemeContext on BuildContext {
  PrestoOverlayTheme get prestoOverlayTheme =>
      Theme.of(this).extension<PrestoOverlayTheme>() ??
      PrestoOverlayTheme.fallback;
}
