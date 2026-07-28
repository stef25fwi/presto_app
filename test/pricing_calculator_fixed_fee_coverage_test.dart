import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/pricing_calculator_page.dart';

void main() {
  testWidgets('updates the Standard fixed selling-fee field', (tester) async {
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

    await tester.tap(euroToggle.last);
    await tester.pump();
    final fixedFeeRow = find.ancestor(
      of: find.text('Frais fixes par vente :'),
      matching: find.byType(Row),
    ).first;
    final fixedFeeField = find.descendant(
      of: fixedFeeRow,
      matching: find.byType(TextField),
    );
    await tester.enterText(fixedFeeField, '4,50');
    await tester.pump();

    expect(find.text('4,50'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Calculer mon prix conseillé'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    final calculateButton = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Calculer mon prix conseillé'),
        matching: find.byType(InkWell),
      ).first,
    );
    expect(calculateButton.onTap, isNotNull);
  });
}
