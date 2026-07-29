import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/pricing_calculator_page.dart';

void main() {
  testWidgets('Standard results return to retained pricing assumptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PrestoPriceCalculatorApp());
    await tester.scrollUntilVisible(
      find.text('Commencer'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('project-name')),
      'Bougies artisanales',
    );
    await tester.scrollUntilVisible(
      find.text('Calculer mon prix conseillé'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Calculer mon prix conseillé'));
    await tester.pumpAndSettle();

    expect(find.text('Résultats Standard'), findsOneWidget);
    expect(find.text('Bougies artisanales'), findsOneWidget);
    expect(find.text('Sauvegarder cette analyse'), findsNothing);
    expect(find.text('Exporter en PDF'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Ajuster mes hypothèses'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Ajuster mes hypothèses'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('project-name')),
      -500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Résultats Standard'), findsNothing);
    final projectField = tester.widget<TextField>(
      find.byKey(const ValueKey('project-name')),
    );
    expect(projectField.controller?.text, 'Bougies artisanales');
  });
}
