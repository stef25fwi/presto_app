import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/presto_overlay_theme.dart';

void main() {
  test('fallback expose les formes attendues', () {
    final theme = PrestoOverlayTheme.fallback;

    final dialog = theme.dialogShape as RoundedRectangleBorder;
    final sheet = theme.sheetShape as RoundedRectangleBorder;
    final popup = theme.popupShape as RoundedRectangleBorder;

    expect(dialog.borderRadius, theme.dialogRadius);
    expect(dialog.side.color, theme.borderColor);
    expect(sheet.borderRadius, theme.sheetRadius);
    expect(sheet.side.color, theme.borderColor);
    expect(popup.borderRadius, theme.popupRadius);
    expect(popup.side.color, theme.borderColor);
  });

  test('copyWith conserve les valeurs absentes et remplace les autres', () {
    final original = PrestoOverlayTheme.fallback;
    const newSurface = Color(0xFF112233);
    const newAccent = Color(0xFF445566);
    const newRadius = BorderRadius.all(Radius.circular(8));

    final copy = original.copyWith(
      surfaceColor: newSurface,
      selectionAccentColor: newAccent,
      popupRadius: newRadius,
    );

    expect(copy.surfaceColor, newSurface);
    expect(copy.selectionAccentColor, newAccent);
    expect(copy.popupRadius, newRadius);
    expect(copy.surfaceTintColor, original.surfaceTintColor);
    expect(copy.borderColor, original.borderColor);
    expect(copy.selectionFillColor, original.selectionFillColor);
    expect(copy.shadowColor, original.shadowColor);
    expect(copy.dialogRadius, original.dialogRadius);
    expect(copy.sheetRadius, original.sheetRadius);
  });

  test('lerp interpole toutes les propriétés et ignore un autre type', () {
    final start = PrestoOverlayTheme.fallback;
    final end = start.copyWith(
      surfaceColor: Colors.black,
      surfaceTintColor: Colors.red,
      borderColor: Colors.green,
      selectionFillColor: Colors.yellow,
      selectionAccentColor: Colors.purple,
      shadowColor: Colors.blue,
      dialogRadius: const BorderRadius.all(Radius.circular(10)),
      sheetRadius: const BorderRadius.all(Radius.circular(12)),
      popupRadius: const BorderRadius.all(Radius.circular(14)),
    );

    final middle = start.lerp(end, 0.5);

    expect(middle.surfaceColor, Color.lerp(start.surfaceColor, end.surfaceColor, 0.5));
    expect(middle.surfaceTintColor,
        Color.lerp(start.surfaceTintColor, end.surfaceTintColor, 0.5));
    expect(middle.borderColor, Color.lerp(start.borderColor, end.borderColor, 0.5));
    expect(middle.selectionFillColor,
        Color.lerp(start.selectionFillColor, end.selectionFillColor, 0.5));
    expect(middle.selectionAccentColor,
        Color.lerp(start.selectionAccentColor, end.selectionAccentColor, 0.5));
    expect(middle.shadowColor, Color.lerp(start.shadowColor, end.shadowColor, 0.5));
    expect(middle.dialogRadius,
        BorderRadius.lerp(start.dialogRadius, end.dialogRadius, 0.5));
    expect(middle.sheetRadius,
        BorderRadius.lerp(start.sheetRadius, end.sheetRadius, 0.5));
    expect(middle.popupRadius,
        BorderRadius.lerp(start.popupRadius, end.popupRadius, 0.5));

    expect(start.lerp(const _OtherTheme(), 0.5), same(start));
  });

  testWidgets('extension de contexte retourne extension puis fallback', (tester) async {
    PrestoOverlayTheme? withExtension;
    PrestoOverlayTheme? withoutExtension;
    final custom = PrestoOverlayTheme.fallback.copyWith(
      surfaceColor: const Color(0xFFABCDEF),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: <ThemeExtension<dynamic>>[custom]),
        home: Builder(
          builder: (context) {
            withExtension = context.prestoOverlayTheme;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(withExtension, same(custom));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            withoutExtension = context.prestoOverlayTheme;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(withoutExtension, same(PrestoOverlayTheme.fallback));
  });
}

@immutable
class _OtherTheme extends ThemeExtension<_OtherTheme> {
  const _OtherTheme();

  @override
  _OtherTheme copyWith() => this;

  @override
  _OtherTheme lerp(covariant ThemeExtension<_OtherTheme>? other, double t) => this;
}
