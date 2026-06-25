import 'package:flutter/material.dart';

/// Available font families selectable from the admin typography panel.
const List<String> kAvailableFontFamilies = ['Inter', 'Rubik'];

class TypographySettings extends ChangeNotifier {
  double _scale = 1.0;
  String _fontFamily = 'Inter';

  double get scale => _scale;
  String get fontFamily => _fontFamily;

  void apply({required double scale, required String fontFamily}) {
    _scale = scale;
    _fontFamily = fontFamily;
    notifyListeners();
  }

  void reset() {
    _scale = 1.0;
    _fontFamily = 'Inter';
    notifyListeners();
  }
}

/// App-wide singleton — imported wherever needed.
final typographySettings = TypographySettings();
