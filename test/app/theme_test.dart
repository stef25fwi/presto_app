import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/presto_overlay_theme.dart';
import 'package:presto_app/app/theme.dart';

void main() {
  test('buildPrestoTheme retourne le singleton configuré', () {
    final first = buildPrestoTheme();
    final second = buildPrestoTheme();

    expect(identical(first, second), isTrue);
    expect(first.useMaterial3, isTrue);
    expect(first.fontFamily, 'Inter');
    expect(first.colorScheme.primary, const Color(0xFF1A73E8));
    expect(first.scaffoldBackgroundColor, const Color(0xFFFDF4EC));
    expect(first.canvasColor, Colors.white);
    expect(first.cardColor, Colors.white);
  });

  test('configure les surfaces, textes et overlays Presto', () {
    final theme = buildPrestoTheme();
    final overlay = theme.extension<PrestoOverlayTheme>();

    expect(overlay, isNotNull);
    expect(overlay!.surfaceColor, Colors.white);
    expect(overlay.borderColor, const Color(0xFFD7DEE8));
    expect(theme.splashColor, overlay.selectionFillColor);
    expect(theme.highlightColor, overlay.selectionFillColor);
    expect(theme.dialogTheme.shape, overlay.dialogShape);
    expect(theme.bottomSheetTheme.shape, overlay.sheetShape);
    expect(theme.popupMenuTheme.shape, overlay.popupShape);
    expect(theme.listTileTheme.selectedColor, overlay.selectionAccentColor);
    expect(theme.textTheme.titleLarge, isNotNull);
    expect(theme.textTheme.bodyMedium, isNotNull);
  });

  test('configure AppBar, champs, menus et boutons', () {
    final theme = buildPrestoTheme();
    final overlay = theme.extension<PrestoOverlayTheme>()!;
    final systemStyle = theme.appBarTheme.systemOverlayStyle;

    expect(theme.appBarTheme.centerTitle, isTrue);
    expect(theme.appBarTheme.backgroundColor, const Color(0xFF1A73E8));
    expect(theme.appBarTheme.foregroundColor, Colors.white);
    expect(systemStyle?.statusBarIconBrightness, Brightness.light);
    expect(systemStyle?.systemNavigationBarIconBrightness, Brightness.dark);
    expect(theme.bottomSheetTheme.showDragHandle, isTrue);
    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(theme.inputDecorationTheme.focusedBorder, isA<OutlineInputBorder>());
    expect(
      theme.menuTheme.style?.backgroundColor?.resolve(<WidgetState>{}),
      overlay.surfaceColor,
    );
    expect(theme.textButtonTheme.style, isNotNull);
    expect(theme.elevatedButtonTheme.style, isNotNull);
    expect(theme.filledButtonTheme.style, isNotNull);
  });

  testWidgets('extension de contexte retrouve le thème overlay', (tester) async {
    late PrestoOverlayTheme resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPrestoTheme(),
        home: Builder(
          builder: (context) {
            resolved = context.prestoOverlayTheme;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(resolved.surfaceColor, Colors.white);
    expect(resolved.popupRadius, const BorderRadius.all(Radius.circular(18)));
  });
}
