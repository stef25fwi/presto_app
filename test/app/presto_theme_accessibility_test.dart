import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/theme.dart';

void main() {
  group('buildPrestoTheme', () {
    test('utilise la charte nationale sans fond beige', () {
      final theme = buildPrestoTheme();

      expect(theme.fontFamily, 'Inter');
      expect(theme.colorScheme.primary, const Color(0xFF1A73E8));
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF7F9FC));
      expect(theme.scaffoldBackgroundColor, isNot(const Color(0xFFFDF4EC)));
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(theme.inputDecorationTheme.fillColor, Colors.white);
    });

    test('impose des cibles tactiles de 48 px aux boutons principaux', () {
      final theme = buildPrestoTheme();
      const states = <WidgetState>{};
      const expected = Size(
        kPrestoMinInteractiveDimension,
        kPrestoMinInteractiveDimension,
      );

      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
      expect(theme.visualDensity, VisualDensity.standard);
      expect(theme.textButtonTheme.style?.minimumSize?.resolve(states), expected);
      expect(
        theme.outlinedButtonTheme.style?.minimumSize?.resolve(states),
        expected,
      );
      expect(
        theme.elevatedButtonTheme.style?.minimumSize?.resolve(states),
        expected,
      );
      expect(theme.filledButtonTheme.style?.minimumSize?.resolve(states), expected);
      expect(theme.iconButtonTheme.style?.minimumSize?.resolve(states), expected);
    });

    test('rend le focus et les erreurs de formulaire visibles', () {
      final theme = buildPrestoTheme();
      final focused = theme.inputDecorationTheme.focusedBorder as OutlineInputBorder;
      final error = theme.inputDecorationTheme.focusedErrorBorder
          as OutlineInputBorder;

      expect(theme.focusColor, const Color(0x331A73E8));
      expect(focused.borderSide.color, const Color(0xFF1A73E8));
      expect(focused.borderSide.width, 2);
      expect(error.borderSide.color, const Color(0xFFB91C1C));
      expect(error.borderSide.width, 2);
    });

    testWidgets('les boutons héritent réellement de la cible minimale', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPrestoTheme(),
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(onPressed: () {}, child: const Text('Texte')),
                  OutlinedButton(onPressed: () {}, child: const Text('Contour')),
                  ElevatedButton(onPressed: () {}, child: const Text('Élevé')),
                  FilledButton(onPressed: () {}, child: const Text('Rempli')),
                  IconButton(
                    onPressed: () {},
                    tooltip: 'Action accessible',
                    icon: const Icon(Icons.check),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      for (final type in <Type>[
        TextButton,
        OutlinedButton,
        ElevatedButton,
        FilledButton,
        IconButton,
      ]) {
        final size = tester.getSize(find.byType(type));
        expect(size.width, greaterThanOrEqualTo(kPrestoMinInteractiveDimension));
        expect(size.height, greaterThanOrEqualTo(kPrestoMinInteractiveDimension));
      }
    });
  });
}
