import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/presto_design_tokens.dart';
import 'package:presto_app/app/theme.dart';

void main() {
  group('contrastes du design system', () {
    test('les couples de texte officiels atteignent WCAG AA', () {
      expect(
        prestoContrastRatio(
          PrestoColors.textOnBlue,
          PrestoColors.brandBlue,
        ),
        greaterThanOrEqualTo(PrestoAccessibility.normalTextContrast),
      );
      expect(
        prestoContrastRatio(
          PrestoColors.textOnOrange,
          PrestoColors.brandOrange,
        ),
        greaterThanOrEqualTo(PrestoAccessibility.normalTextContrast),
      );
      expect(
        prestoContrastRatio(
          PrestoColors.textPrimary,
          PrestoColors.surface,
        ),
        greaterThanOrEqualTo(PrestoAccessibility.normalTextContrast),
      );
      expect(
        prestoContrastRatio(
          PrestoColors.textSecondary,
          PrestoColors.surface,
        ),
        greaterThanOrEqualTo(PrestoAccessibility.normalTextContrast),
      );
    });

    test('le blanc sur orange reste explicitement interdit au texte normal', () {
      expect(
        prestoContrastRatio(Colors.white, PrestoColors.brandOrange),
        lessThan(PrestoAccessibility.normalTextContrast),
      );
    });
  });

  test('les breakpoints classent les largeurs cibles', () {
    expect(
      PrestoBreakpoints.classify(320),
      PrestoWindowClass.compact,
    );
    expect(
      PrestoBreakpoints.classify(599),
      PrestoWindowClass.compact,
    );
    expect(
      PrestoBreakpoints.classify(600),
      PrestoWindowClass.medium,
    );
    expect(
      PrestoBreakpoints.classify(1023),
      PrestoWindowClass.medium,
    );
    expect(
      PrestoBreakpoints.classify(1024),
      PrestoWindowClass.expanded,
    );
    expect(
      PrestoBreakpoints.classify(1440),
      PrestoWindowClass.expanded,
    );
  });

  test('le thème applique la palette et une cible minimale de 48 px', () {
    final theme = buildPrestoTheme();
    final states = <WidgetState>{};

    Size minimumSize(ButtonStyle? style) {
      return style?.minimumSize?.resolve(states) ?? Size.zero;
    }

    expect(theme.colorScheme.primary, PrestoColors.brandBlue);
    expect(theme.colorScheme.onPrimary, PrestoColors.textOnBlue);
    expect(theme.colorScheme.secondary, PrestoColors.brandOrange);
    expect(theme.colorScheme.onSecondary, PrestoColors.textOnOrange);
    expect(theme.scaffoldBackgroundColor, PrestoColors.scaffold);

    for (final size in <Size>[
      minimumSize(theme.textButtonTheme.style),
      minimumSize(theme.elevatedButtonTheme.style),
      minimumSize(theme.filledButtonTheme.style),
      minimumSize(theme.outlinedButtonTheme.style),
      minimumSize(theme.iconButtonTheme.style),
    ]) {
      expect(size.width, greaterThanOrEqualTo(PrestoAccessibility.minTouchTarget));
      expect(size.height, greaterThanOrEqualTo(PrestoAccessibility.minTouchTarget));
    }
  });

  testWidgets('les actions communes restent utilisables au clavier', (
    tester,
  ) async {
    final firstFocus = FocusNode(debugLabel: 'première action');
    final secondFocus = FocusNode(debugLabel: 'deuxième action');
    addTearDown(firstFocus.dispose);
    addTearDown(secondFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPrestoTheme(),
        home: Scaffold(
          body: Column(
            children: [
              TextButton(
                focusNode: firstFocus,
                onPressed: () {},
                child: const Text('Première action'),
              ),
              FilledButton(
                focusNode: secondFocus,
                onPressed: () {},
                child: const Text('Deuxième action'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(firstFocus.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(secondFocus.hasFocus, isTrue);
  });

  testWidgets('un bouton essentiel supporte 320 px et un texte à 200 %', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPrestoTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(
              PrestoAccessibility.requiredTextScale,
            ),
          ),
          child: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 288),
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('Publier mon annonce'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(PrestoAccessibility.minTouchTarget),
    );
  });
}
