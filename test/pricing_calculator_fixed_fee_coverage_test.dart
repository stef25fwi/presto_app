import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/pricing_calculator_page.dart';

void main() {
  testWidgets('updates the fixed selling fee field', (tester) async {
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
      find.text('4. Frais de Vente'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    final typeRow = find.ancestor(
      of: find.text('Type :'),
      matching: find.byType(Row),
    ).first;
    final euroToggle = find.descendant(of: typeRow, matching: find.text('€'));

    await tester.tap(euroToggle.last);
    await tester.pump();
    expect(find.text('Frais fixes par vente :'), findsOneWidget);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(11));
    await tester.enterText(fields.at(7), '4,50');
    await tester.pump();

    expect(find.text('4,50'), findsOneWidget);
    final calculateButton = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Voir mon Prix Conseillé'),
        matching: find.byType(InkWell),
      ).first,
    );
    expect(calculateButton.onTap, isNotNull);
  });
}
