import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/entrepreneur_pricing/entrepreneur_pricing_models.dart';
import 'package:presto_app/pages/entrepreneur_pricing/entrepreneur_pricing_results_page.dart';

EntrepreneurPricingDraft _draft({
  required EntrepreneurPricingMode mode,
  List<ProductionMachineUsage> machines = const <ProductionMachineUsage>[],
  List<ProductionAccessoryUsage> accessories =
      const <ProductionAccessoryUsage>[],
}) {
  return EntrepreneurPricingDraft(
    projectName: mode == EntrepreneurPricingMode.expert
        ? 'Atelier expert'
        : 'Projet standard',
    mode: mode,
    expectedPriceTtc: 42,
    materials: 10,
    packaging: 2,
    consumables: 1,
    workMinutes: 45,
    hourlyRate: 20,
    monthlyFixedCosts: 300,
    monthlyVolume: 20,
    equipmentInvestment: 1200,
    equipmentSharePerUnit: 2,
    externalFeePercent: 3,
    externalFixedFee: 0.5,
    marginPercent: 25,
    vatPercent: 8.5,
    regionCode: '971',
    electricityRate: 0.25,
    waterM3PerUnit: 0.01,
    waterRate: 4,
    transportPerUnit: 1.5,
    otherCostsPerUnit: 0.5,
    machines: machines,
    accessories: accessories,
    marketLow: 35,
    marketMid: 42,
    marketHigh: 55,
    prudentVolume: 10,
    highVolume: 30,
  );
}

EntrepreneurPricingCalculation _calculation({int breakEvenUnits = 12}) {
  return EntrepreneurPricingCalculation(
    materialCost: 13,
    accessoryCost: 2.5,
    machineKwh: 0.4,
    machineElectricityCost: 0.1,
    waterCost: 0.04,
    transportAndOtherCost: 2,
    laborCost: 15,
    fixedCostPerUnit: 15,
    amortizationPerUnit: 2,
    costPrice: 49.64,
    minimumPriceTtc: 56,
    suggestedPriceTtc: 68,
    expectedUnitProfit: 4,
    suggestedUnitProfit: 14,
    unitsToAmortize: 600,
    breakEvenUnits: breakEvenUnits,
    expectedPriceIsProfitable: true,
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required EntrepreneurPricingDraft draft,
  required EntrepreneurPricingCalculation calculation,
}) async {
  tester.view.physicalSize = const Size(1200, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: EntrepreneurPricingResultsPage(
        draft: draft,
        calculation: calculation,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('le mode Standard affiche la synthèse sans blocs experts',
      (tester) async {
    await _pumpPage(
      tester,
      draft: _draft(mode: EntrepreneurPricingMode.standard),
      calculation: _calculation(breakEvenUnits: 0),
    );

    expect(find.text('Résultats Standard'), findsOneWidget);
    expect(find.text('Projet standard'), findsOneWidget);
    expect(find.text('Synthèse du prix'), findsOneWidget);
    expect(find.text('Coût exact de production'), findsOneWidget);
    expect(find.text('Coût de revient'), findsOneWidget);
    expect(find.text('Prix minimum rentable TTC'), findsOneWidget);
    expect(find.text('Prix conseillé TTC'), findsOneWidget);
    expect(find.text('Marge au prix conseillé'), findsOneWidget);
    expect(find.text('Non calculable'), findsOneWidget);
    expect(find.text('Matières et consommables'), findsOneWidget);
    expect(find.text('Main-d’œuvre'), findsOneWidget);
    expect(find.text('Charges fixes'), findsOneWidget);
    expect(find.text('Amortissement'), findsOneWidget);
    expect(find.text('Ajuster mes hypothèses'), findsOneWidget);

    expect(find.text('Machines prises en compte'), findsNothing);
    expect(find.text('Accessoires pris en compte'), findsNothing);
    expect(find.text('Scénarios mensuels'), findsNothing);
    expect(find.text('Sauvegarder cette analyse'), findsNothing);
    expect(find.text('Générer la fiche PDF'), findsNothing);
    expect(find.text('Eau'), findsNothing);
    expect(find.text('Transport et autres'), findsNothing);
  });

  testWidgets('le mode Expert affiche coûts avancés machines et scénarios',
      (tester) async {
    const machine = ProductionMachineUsage(
      name: 'Four',
      watts: 1200,
      minutesPerUnit: 15,
      quantity: 2,
    );
    const accessory = ProductionAccessoryUsage(
      name: 'Moule',
      quantityPerUnit: 1.5,
      unitPrice: 2,
    );

    await _pumpPage(
      tester,
      draft: _draft(
        mode: EntrepreneurPricingMode.expert,
        machines: const <ProductionMachineUsage>[machine],
        accessories: const <ProductionAccessoryUsage>[accessory],
      ),
      calculation: _calculation(),
    );

    expect(find.text('Analyse experte'), findsOneWidget);
    expect(find.text('Atelier expert'), findsOneWidget);
    expect(find.text('12 unités / mois'), findsOneWidget);
    expect(find.text('Accessoires'), findsOneWidget);
    expect(find.textContaining('Machines ('), findsOneWidget);
    expect(find.text('Eau'), findsOneWidget);
    expect(find.text('Transport et autres'), findsOneWidget);

    expect(find.text('Machines prises en compte'), findsOneWidget);
    expect(find.textContaining('Four • 1200 W × 15,0 min × 2'), findsOneWidget);
    expect(find.text('Accessoires pris en compte'), findsOneWidget);
    expect(find.textContaining('Moule • 1,50 × 2,00 €'), findsOneWidget);

    expect(find.text('Scénarios mensuels'), findsOneWidget);
    expect(find.textContaining('Prudent • 10 unités'), findsOneWidget);
    expect(find.textContaining('Cible • 20 unités'), findsOneWidget);
    expect(find.textContaining('Haut • 30 unités'), findsOneWidget);
    expect(find.text('Sauvegarder cette analyse'), findsOneWidget);
    expect(find.text('Générer la fiche PDF'), findsOneWidget);
    expect(find.text('Ajuster mes hypothèses'), findsOneWidget);
  });
}
