import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/pricing_calculator_page.dart';

void main() {
  testWidgets('covers Standard selling-fee toggle and app bar back', (
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

    await tester.scrollUntilVisible(
      find.text('6. Frais, marge et fiscalité'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    final typeRow = find.ancestor(
      of: find.text('Type :'),
      matching: find.byType(Row),
    ).first;
    final euroToggle = find.descendant(of: typeRow, matching: find.text('€'));
    final percentageToggle =
        find.descendant(of: typeRow, matching: find.text('%'));

    await tester.tap(euroToggle.last);
    await tester.pump();
    expect(find.text('Frais fixes par vente :'), findsOneWidget);

    await tester.tap(percentageToggle.last);
    await tester.pump();
    expect(find.text('Frais de vente externes :'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Calculer mon prix conseillé'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Calculer mon prix conseillé'));
    await tester.pumpAndSettle();

    expect(find.text('Résultats Standard'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Mode Standard'),
      -500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mode Standard'), findsOneWidget);
    expect(find.text('Résultats Standard'), findsNothing);
  });
}
