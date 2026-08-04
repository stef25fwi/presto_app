import 'package:flutter/material.dart';

/// Palette officielle iliprestō.
///
/// Les couleurs de marque ne doivent pas être utilisées sans vérifier le
/// contraste du couple premier plan / arrière-plan. En particulier, le blanc
/// sur l’orange de marque n’atteint pas WCAG AA pour du texte normal : les
/// boutons orange utilisent donc [textPrimary].
abstract final class PrestoColors {
  static const brandOrange = Color(0xFFFF6600);

  /// Orange de marque assombri, réservé au **texte** sur fond clair.
  ///
  /// L’orange de marque ne dépasse pas 2,94:1 sur blanc : il échoue même au
  /// seuil du texte large. Cette variante atteint 5,01:1 sur la surface et
  /// 4,61:1 sur le fond de l’application. L’orange d’origine reste réservé aux
  /// aplats, jamais au texte.
  static const brandOrangeText = Color(0xFFBF4A00);

  static const brandBlue = Color(0xFF1A73E8);
  static const brandBlueDark = Color(0xFF175DB8);

  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textOnBlue = Colors.white;
  static const textOnOrange = textPrimary;

  static const surface = Colors.white;
  static const scaffold = Color(0xFFFDF4EC);
  static const surfaceMuted = Color(0xFFF4F7FB);
  static const surfaceSelected = Color(0xFFEAF2FF);
  static const border = Color(0xFFD7DEE8);

  /// Remplissage discret appliqué à l’élément qui reçoit le focus.
  ///
  /// Ce ton ne suffit pas à signaler le focus : il n’atteint que 1,2:1 sur les
  /// fonds clairs. Il est conservé comme fond, jamais comme indicateur.
  static const focus = Color(0xFFE2E8F0);

  /// Anneau de focus visible, seul indicateur opposable.
  ///
  /// Atteint 6,4:1 sur [surface] et 5,9:1 sur [scaffold], au-delà des 3:1
  /// exigés par WCAG 2.2 pour un composant non textuel.
  static const focusRing = brandBlueDark;

  static const hover = Color(0xFFF1F5F9);
  static const shadow = Color(0x140F172A);

  static const success = Color(0xFF0F766E);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFB42318);
}

abstract final class PrestoSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class PrestoRadii {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
  static const hero = 28.0;
}

abstract final class PrestoBreakpoints {
  static const compact = 600.0;
  static const medium = 1024.0;
  static const expanded = 1440.0;

  static PrestoWindowClass classify(double width) {
    if (width < compact) return PrestoWindowClass.compact;
    if (width < medium) return PrestoWindowClass.medium;
    return PrestoWindowClass.expanded;
  }
}

enum PrestoWindowClass { compact, medium, expanded }

abstract final class PrestoAccessibility {
  /// Minimum WCAG / Material recommandé pour une cible interactive.
  static const minTouchTarget = 48.0;

  /// Facteur de texte devant être supporté sans perte d’action essentielle.
  static const requiredTextScale = 2.0;

  /// Ratio minimal WCAG AA pour du texte normal.
  static const normalTextContrast = 4.5;

  /// Ratio minimal WCAG AA pour du texte large et les composants graphiques.
  static const largeTextContrast = 3.0;

  /// Ratio minimal WCAG 2.2 (1.4.11) pour un indicateur de focus.
  static const focusIndicatorContrast = 3.0;

  /// Épaisseur minimale de l’anneau de focus, en pixels logiques.
  static const focusRingWidth = 2.0;

  /// Largeurs de référence testées, de la plus petite à la plus grande.
  static const responsiveWidths = <double>[320, 375, 600, 1024, 1440];

  /// Facteurs de texte couverts par la matrice responsive.
  static const textScales = <double>[1.0, 1.5, 2.0];
}

/// Calcule le ratio de contraste WCAG de deux couleurs opaques.
double prestoContrastRatio(Color foreground, Color background) {
  assert(foreground.a == 1.0, 'La couleur de premier plan doit être opaque.');
  assert(background.a == 1.0, 'La couleur de fond doit être opaque.');
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
