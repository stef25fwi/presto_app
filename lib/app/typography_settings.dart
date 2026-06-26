import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available font families selectable from the admin typography panel.
const List<String> kAvailableFontFamilies = ['Inter', 'Rubik'];

const _kPrefScale = 'typo_scale';
const _kPrefFamily = 'typo_family';
const _kPrefWeightDelta = 'typo_weight_delta';

class TypographySettings extends ChangeNotifier {
  double _scale = 1.0;
  String _fontFamily = 'Inter';
  int _fontWeightDelta = 0;

  double get scale => _scale;
  String get fontFamily => _fontFamily;

  /// Shift applied to every font weight in the theme (-2 to +2 steps).
  /// Each step moves one slot in the w100…w900 ladder.
  int get fontWeightDelta => _fontWeightDelta;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _scale = prefs.getDouble(_kPrefScale) ?? 1.0;
    _fontFamily = prefs.getString(_kPrefFamily) ?? 'Inter';
    _fontWeightDelta = prefs.getInt(_kPrefWeightDelta) ?? 0;
    notifyListeners();
  }

  void apply({
    required double scale,
    required String fontFamily,
    int fontWeightDelta = 0,
  }) {
    _scale = scale;
    _fontFamily = fontFamily;
    _fontWeightDelta = fontWeightDelta;
    notifyListeners();
    _persist(scale: scale, fontFamily: fontFamily, fontWeightDelta: fontWeightDelta);
  }

  void reset() {
    _scale = 1.0;
    _fontFamily = 'Inter';
    _fontWeightDelta = 0;
    notifyListeners();
    _persist(scale: 1.0, fontFamily: 'Inter', fontWeightDelta: 0);
  }

  Future<void> _persist({
    required double scale,
    required String fontFamily,
    required int fontWeightDelta,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kPrefScale, scale);
    await prefs.setString(_kPrefFamily, fontFamily);
    await prefs.setInt(_kPrefWeightDelta, fontWeightDelta);
  }
}

/// App-wide singleton — imported wherever needed.
final typographySettings = TypographySettings();

// ─── Helpers ─────────────────────────────────────────────────────────────────

const _kWeights = [
  FontWeight.w100,
  FontWeight.w200,
  FontWeight.w300,
  FontWeight.w400,
  FontWeight.w500,
  FontWeight.w600,
  FontWeight.w700,
  FontWeight.w800,
  FontWeight.w900,
];

FontWeight shiftFontWeight(FontWeight? weight, int delta) {
  if (delta == 0) return weight ?? FontWeight.w400;
  final idx = _kWeights.indexOf(weight ?? FontWeight.w400);
  final base = idx < 0 ? 3 : idx; // default w400 = index 3
  return _kWeights[(base + delta).clamp(0, 8)];
}

TextStyle _shiftStyle(TextStyle? style, int delta) {
  if (style == null) return const TextStyle();
  if (delta == 0) return style;
  return style.copyWith(fontWeight: shiftFontWeight(style.fontWeight, delta));
}

TextTheme shiftTextThemeWeight(TextTheme theme, int delta) {
  if (delta == 0) return theme;
  return theme.copyWith(
    displayLarge: _shiftStyle(theme.displayLarge, delta),
    displayMedium: _shiftStyle(theme.displayMedium, delta),
    displaySmall: _shiftStyle(theme.displaySmall, delta),
    headlineLarge: _shiftStyle(theme.headlineLarge, delta),
    headlineMedium: _shiftStyle(theme.headlineMedium, delta),
    headlineSmall: _shiftStyle(theme.headlineSmall, delta),
    titleLarge: _shiftStyle(theme.titleLarge, delta),
    titleMedium: _shiftStyle(theme.titleMedium, delta),
    titleSmall: _shiftStyle(theme.titleSmall, delta),
    bodyLarge: _shiftStyle(theme.bodyLarge, delta),
    bodyMedium: _shiftStyle(theme.bodyMedium, delta),
    bodySmall: _shiftStyle(theme.bodySmall, delta),
    labelLarge: _shiftStyle(theme.labelLarge, delta),
    labelMedium: _shiftStyle(theme.labelMedium, delta),
    labelSmall: _shiftStyle(theme.labelSmall, delta),
  );
}
