import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/entrepreneur_pricing/entrepreneur_pricing_models.dart';
import 'package:presto_app/pages/entrepreneur_pricing/entrepreneur_pricing_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('génère une fiche PDF valide avec machines et accessoires', () async {
    const draft = EntrepreneurPricingDraft(
      projectName: 'Atelier test',
      mode: EntrepreneurPricingMode.expert,
      expectedPriceTtc: 60,
      materials: 10,
      packaging: 1,
      consumables: 2,
      workMinutes: 30,
      hourlyRate: 20,
      monthlyFixedCosts: 100,
      monthlyVolume: 10,
      equipmentInvestment: 100,
      equipmentSharePerUnit: 5,
      externalFeePercent: 0,
      externalFixedFee: 0,
      marginPercent: 20,
      vatPercent: 0,
      regionCode: '971',
      electricityRate: 0.25,
      waterM3PerUnit: 0,
      waterRate: 0,
      transportPerUnit: 0,
      otherCostsPerUnit: 0,
      machines: [
        ProductionMachineUsage(
          name: 'Four',
          watts: 1000,
          minutesPerUnit: 30,
        ),
      ],
      accessories: [
        ProductionAccessoryUsage(
          name: 'Filtre',
          quantityPerUnit: 2,
          unitPrice: 1.5,
        ),
      ],
      marketLow: 40,
      marketMid: 50,
      marketHigh: 60,
      prudentVolume: 5,
      highVolume: 15,
    );

    final bytes = await EntrepreneurPricingPdfExporter.build(
      draft: draft,
      calculation: EntrepreneurPricingEngine.compute(draft),
    );

    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });
}