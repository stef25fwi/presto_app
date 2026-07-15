import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/typography_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads persisted typography settings and notifies listeners', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'typo_scale': 1.25,
      'typo_family': 'Rubik',
      'typo_weight_delta': 2,
    });
    final settings = TypographySettings();
    var notifications = 0;
    settings.addListener(() => notifications++);

    await settings.load();

    expect(settings.scale, 1.25);
    expect(settings.fontFamily, 'Rubik');
    expect(settings.fontWeightDelta, 2);
    expect(notifications, 1);
  });

  test('loads safe defaults when no preference exists', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = TypographySettings();

    await settings.load();

    expect(settings.scale, 1);
    expect(settings.fontFamily, 'Inter');
    expect(settings.fontWeightDelta, 0);
  });

  test('applies, persists and resets typography settings', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = TypographySettings();
    var notifications = 0;
    settings.addListener(() => notifications++);

    settings.apply(
      scale: 1.3,
      fontFamily: 'Nunito',
      fontWeightDelta: -1,
    );
    await Future<void>.delayed(Duration.zero);

    expect(settings.scale, 1.3);
    expect(settings.fontFamily, 'Nunito');
    expect(settings.fontWeightDelta, -1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('typo_scale'), 1.3);
    expect(prefs.getString('typo_family'), 'Nunito');
    expect(prefs.getInt('typo_weight_delta'), -1);

    settings.reset();
    await Future<void>.delayed(Duration.zero);
    expect(settings.scale, 1);
    expect(settings.fontFamily, 'Inter');
    expect(settings.fontWeightDelta, 0);
    expect(notifications, 2);
    expect(prefs.getDouble('typo_scale'), 1);
    expect(prefs.getString('typo_family'), 'Inter');
    expect(prefs.getInt('typo_weight_delta'), 0);
  });

  test('shifts font weights with defaults and clamped boundaries', () {
    expect(shiftFontWeight(null, 0), FontWeight.w400);
    expect(shiftFontWeight(FontWeight.w600, 0), FontWeight.w600);
    expect(shiftFontWeight(FontWeight.w400, 2), FontWeight.w600);
    expect(shiftFontWeight(FontWeight.w400, -2), FontWeight.w200);
    expect(shiftFontWeight(FontWeight.w900, 2), FontWeight.w900);
    expect(shiftFontWeight(FontWeight.w100, -2), FontWeight.w100);
    expect(
      shiftFontWeight(const FontWeight(450), 1),
      FontWeight.w500,
    );
  });

  test('shifts every text theme slot and preserves a zero delta theme', () {
    const theme = TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.w100),
      displayMedium: TextStyle(fontWeight: FontWeight.w200),
      displaySmall: TextStyle(fontWeight: FontWeight.w300),
      headlineLarge: TextStyle(fontWeight: FontWeight.w400),
      headlineMedium: TextStyle(fontWeight: FontWeight.w500),
      headlineSmall: TextStyle(fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontWeight: FontWeight.w800),
      titleSmall: TextStyle(fontWeight: FontWeight.w900),
      bodyLarge: TextStyle(fontWeight: FontWeight.w300),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontWeight: FontWeight.w500),
      labelLarge: TextStyle(fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontWeight: FontWeight.w700),
      labelSmall: TextStyle(fontWeight: FontWeight.w800),
    );

    expect(shiftTextThemeWeight(theme, 0), same(theme));
    final shifted = shiftTextThemeWeight(theme, 1);
    expect(shifted.displayLarge?.fontWeight, FontWeight.w200);
    expect(shifted.headlineLarge?.fontWeight, FontWeight.w500);
    expect(shifted.titleSmall?.fontWeight, FontWeight.w900);
    expect(shifted.bodyMedium?.fontWeight, FontWeight.w500);
    expect(shifted.labelSmall?.fontWeight, FontWeight.w900);

    final withNulls = shiftTextThemeWeight(const TextTheme(), 1);
    expect(withNulls.displayLarge?.fontWeight, isNull);
  });

  test('available font families expose supported options', () {
    expect(kAvailableFontFamilies, containsAll(<String>[
      'Inter',
      'Rubik',
      'Nunito',
      '.SF Pro Display',
    ]));
  });
}
