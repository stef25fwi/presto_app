import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/typography_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('available font families expose the supported choices', () {
    expect(
      kAvailableFontFamilies,
      containsAll(<String>['Inter', 'Rubik', 'Nunito', '.SF Pro Display']),
    );
  });

  test('load keeps defaults and notifies listeners', () async {
    final settings = TypographySettings();
    var notifications = 0;
    settings.addListener(() => notifications++);

    await settings.load();

    expect(settings.scale, 1.0);
    expect(settings.fontFamily, 'Inter');
    expect(settings.fontWeightDelta, 0);
    expect(notifications, 1);
  });

  test('load restores persisted values', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'typo_scale': 1.25,
      'typo_family': 'Rubik',
      'typo_weight_delta': 2,
    });
    final settings = TypographySettings();

    await settings.load();

    expect(settings.scale, 1.25);
    expect(settings.fontFamily, 'Rubik');
    expect(settings.fontWeightDelta, 2);
  });

  test('apply updates state, notifies and persists values', () async {
    final settings = TypographySettings();
    var notifications = 0;
    settings.addListener(() => notifications++);

    settings.apply(scale: 0.9, fontFamily: 'Nunito', fontWeightDelta: -1);
    await Future<void>.delayed(Duration.zero);

    expect(settings.scale, 0.9);
    expect(settings.fontFamily, 'Nunito');
    expect(settings.fontWeightDelta, -1);
    expect(notifications, 1);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('typo_scale'), 0.9);
    expect(prefs.getString('typo_family'), 'Nunito');
    expect(prefs.getInt('typo_weight_delta'), -1);
  });

  test('reset restores and persists defaults', () async {
    final settings = TypographySettings();
    settings.apply(scale: 1.4, fontFamily: 'Rubik', fontWeightDelta: 2);
    await Future<void>.delayed(Duration.zero);

    settings.reset();
    await Future<void>.delayed(Duration.zero);

    expect(settings.scale, 1.0);
    expect(settings.fontFamily, 'Inter');
    expect(settings.fontWeightDelta, 0);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('typo_scale'), 1.0);
    expect(prefs.getString('typo_family'), 'Inter');
    expect(prefs.getInt('typo_weight_delta'), 0);
  });

  group('shiftFontWeight', () {
    test('uses w400 for null or unknown weights', () {
      expect(shiftFontWeight(null, 0), FontWeight.w400);
      expect(shiftFontWeight(const FontWeight(450), 1), FontWeight.w500);
    });

    test('moves weight and clamps at both ends', () {
      expect(shiftFontWeight(FontWeight.w400, 2), FontWeight.w600);
      expect(shiftFontWeight(FontWeight.w100, -5), FontWeight.w100);
      expect(shiftFontWeight(FontWeight.w900, 5), FontWeight.w900);
    });
  });

  test('shiftTextThemeWeight returns original theme for zero delta', () {
    final theme = const TextTheme(bodyMedium: TextStyle(fontWeight: FontWeight.w400));

    expect(identical(shiftTextThemeWeight(theme, 0), theme), isTrue);
  });

  test('shiftTextThemeWeight shifts every style and preserves null slots', () {
    final theme = const TextTheme(
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
    );

    final shifted = shiftTextThemeWeight(theme, 1);

    expect(shifted.displayLarge?.fontWeight, FontWeight.w200);
    expect(shifted.displayMedium?.fontWeight, FontWeight.w300);
    expect(shifted.displaySmall?.fontWeight, FontWeight.w400);
    expect(shifted.headlineLarge?.fontWeight, FontWeight.w500);
    expect(shifted.headlineMedium?.fontWeight, FontWeight.w600);
    expect(shifted.headlineSmall?.fontWeight, FontWeight.w700);
    expect(shifted.titleLarge?.fontWeight, FontWeight.w800);
    expect(shifted.titleMedium?.fontWeight, FontWeight.w900);
    expect(shifted.titleSmall?.fontWeight, FontWeight.w900);
    expect(shifted.bodyLarge?.fontWeight, FontWeight.w400);
    expect(shifted.bodyMedium?.fontWeight, FontWeight.w500);
    expect(shifted.bodySmall?.fontWeight, FontWeight.w600);
    expect(shifted.labelLarge?.fontWeight, FontWeight.w700);
    expect(shifted.labelMedium?.fontWeight, FontWeight.w800);
    expect(shifted.labelSmall, const TextStyle());
  });
}
