import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/pricing_calculator_page.dart';

void main() {
  testWidgets('covers remaining form callbacks, toggle and app bar back', (
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

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(11));

    await tester.enterText(fields.at(4), '32');
    await tester.enterText(fields.at(5), '240');
    await tester.enterText(fields.at(6), '24');
    await tester.enterText(fields.at(7), '8');
    await tester.enterText(fields.at(8), '40');
    await tester.enterText(fields.at(9), '60');
    await tester.enterText(fields.at(10), '80');
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('4. Frais de Vente'),
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
    expect(find.text('Frais de plateforme :'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Voir mon Prix Conseillé'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Voir mon Prix Conseillé'));
    await tester.pumpAndSettle();

    expect(find.text('Résultats & Positionnement'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Mode Express : Estimation Rapide'), findsOneWidget);
    expect(find.text('Résultats & Positionnement'), findsNothing);
  });
}
