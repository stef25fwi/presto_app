import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/entrepreneur_pricing/entrepreneur_pricing_models.dart';
import 'package:presto_app/pages/entrepreneur_pricing/entrepreneur_pricing_results_widgets.dart';

EntrepreneurPricingCalculation _calculation({
  required bool profitable,
  double expectedUnitProfit = 12.5,
}) {
  return EntrepreneurPricingCalculation(
    materialCost: 10,
    accessoryCost: 2,
    machineKwh: 0.4,
    machineElectricityCost: 0.12,
    waterCost: 0.3,
    transportAndOtherCost: 1.5,
    laborCost: 8,
    fixedCostPerUnit: 3,
    amortizationPerUnit: 1,
    costPrice: 25.92,
    minimumPriceTtc: 31.5,
    suggestedPriceTtc: 42,
    expectedUnitProfit: expectedUnitProfit,
    suggestedUnitProfit: 14,
    unitsToAmortize: 20,
    breakEvenUnits: 12,
    expectedPriceIsProfitable: profitable,
  );
}

void main() {
  testWidgets('PricingDecisionCard affiche le diagnostic rentable',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PricingDecisionCard(
            calculation: _calculation(profitable: true),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.textContaining('Ton prix envisagé est rentable'), findsOneWidget);
    expect(find.textContaining('12,50 € / unité'), findsOneWidget);
  });

  testWidgets('PricingDecisionCard affiche le diagnostic déficitaire',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PricingDecisionCard(
            calculation: _calculation(
              profitable: false,
              expectedUnitProfit: -4.25,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.textContaining('À ce prix, tu perds de l’argent'), findsOneWidget);
    expect(find.textContaining('-4,25 € / unité'), findsOneWidget);
  });

  testWidgets('PricingPanel et PricingResultRow rendent leurs contenus',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PricingPanel(
            title: 'Synthèse',
            icon: Icons.analytics_outlined,
            children: <Widget>[
              PricingResultRow('Prix conseillé', '42,00 €', emphasized: true),
              PricingResultRow('Coût', '25,92 €'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Synthèse'), findsOneWidget);
    expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
    expect(find.text('Prix conseillé'), findsOneWidget);
    expect(find.text('42,00 €'), findsOneWidget);
    expect(find.text('Coût'), findsOneWidget);
    expect(find.text('25,92 €'), findsOneWidget);
  });

  testWidgets('PricingActionButton appelle le callback et respecte disabled',
      (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              PricingActionButton(
                text: 'Continuer',
                icon: Icons.arrow_forward_rounded,
                color: pricingOrange,
                onPressed: () => presses++,
              ),
              const PricingActionButton(
                text: 'Indisponible',
                icon: Icons.block_rounded,
                color: pricingBlue,
                onPressed: null,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continuer'));
    await tester.pump();
    expect(presses, 1);

    final disabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Indisponible'),
    );
    expect(disabled.onPressed, isNull);
  });

  testWidgets('PricingAppBar expose sa taille et appelle le retour',
      (tester) async {
    var backCalls = 0;
    const appBarKey = ValueKey<String>('pricing-app-bar');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: PricingAppBar(
            key: appBarKey,
            color: pricingExpertBlue,
            onBack: () => backCalls++,
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    final appBar = tester.widget<PricingAppBar>(find.byKey(appBarKey));
    expect(appBar.preferredSize, const Size.fromHeight(58));
    expect(find.text('iliprestō'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump();
    expect(backCalls, 1);
  });

  test('les formatteurs gèrent nombres, valeurs non finies et dates', () {
    expect(pricingMoney(12.345), '12,35');
    expect(pricingNumber(42.5, 1), '42,5');
    expect(pricingNumber(double.infinity, 2), '0,00');
    expect(pricingNumber(double.nan, 0), '0');
    expect(
      pricingDate(DateTime(2026, 7, 9, 6, 5)),
      '09/07/2026 06:05',
    );
  });
}
