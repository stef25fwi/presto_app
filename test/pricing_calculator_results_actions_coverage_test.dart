import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/pricing_calculator_page.dart';

void main() {
  testWidgets('publishes from results then returns to adjust margins', (
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
      find.text('Voir mon Prix Conseillé'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Voir mon Prix Conseillé'));
    await tester.pumpAndSettle();

    expect(find.text('Résultats & Positionnement'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Publier sur Prestō'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Publier sur Prestō'));
    await tester.pump();
    expect(
      find.text('Action : publier (à connecter à ton flux Prestō)'),
      findsOneWidget,
    );

    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ajuster Marges'));
    await tester.tap(find.text('Ajuster Marges'));
    await tester.pumpAndSettle();

    expect(find.text('Mode Express : Estimation Rapide'), findsOneWidget);
    expect(find.text('Résultats & Positionnement'), findsNothing);
  });
}
