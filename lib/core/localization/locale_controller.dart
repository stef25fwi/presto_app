import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  LocaleController._();

  static final LocaleController instance = LocaleController._();
  static const String _storageKey = 'preferred_language';
  static const List<Locale> supportedLocales = <Locale>[
    Locale('fr'),
    Locale('en'),
    Locale('es'),
  ];

  Locale? _locale;
  bool _initialized = false;

  Locale? get locale => _locale;
  bool get followsSystem => _locale == null;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    final preferences = await SharedPreferences.getInstance();
    final code = preferences.getString(_storageKey)?.trim();
    if (code != null &&
        supportedLocales.any((locale) => locale.languageCode == code)) {
      _locale = Locale(code);
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> useSystemLocale() async {
    _locale = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (!supportedLocales
        .any((supported) => supported.languageCode == locale.languageCode)) {
      throw ArgumentError.value(locale, 'locale', 'Unsupported locale');
    }
    _locale = Locale(locale.languageCode);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, locale.languageCode);
    notifyListeners();
  }

  Locale resolveDeviceLocale(Locale? deviceLocale) {
    final selected = _locale;
    if (selected != null) return selected;
    if (deviceLocale != null &&
        supportedLocales.any(
          (locale) => locale.languageCode == deviceLocale.languageCode,
        )) {
      return Locale(deviceLocale.languageCode);
    }
    return const Locale('fr');
  }
}
