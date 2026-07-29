import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/entrepreneur_pricing/entrepreneur_pricing_models.dart';

void main() {
  group('EntrepreneurPricingEngine', () {
    test('calcule exactement la consommation des machines', () {
      const machine = ProductionMachineUsage(
        name: 'Four',
        watts: 1000,
        minutesPerUnit: 30,
      );

      expect(machine.kwhPerUnit, closeTo(0.5, 0.000001));
      expect(machine.costPerUnit(0.25), closeTo(0.125, 0.000001));
    });

    test('intègre machines et accessoires au coût de production', () {
      final result = EntrepreneurPricingEngine.compute(_draft());

      expect(result.machineKwh, closeTo(0.5, 0.000001));
      expect(result.machineElectricityCost, closeTo(0.125, 0.000001));
      expect(result.accessoryCost, closeTo(3, 0.000001));
      expect(result.materialCost, closeTo(13, 0.000001));
      expect(result.costPrice, closeTo(51.125, 0.000001));
      expect(result.suggestedPriceTtc, closeTo(61.35, 0.000001));
    });

    test('le mode Standard ignore les ressources Expert', () {
      final expert = _draft();
      final standard = EntrepreneurPricingDraft.fromJson({
        ...expert.toJson(),
        'mode': EntrepreneurPricingMode.standard.name,
      });
      final result = EntrepreneurPricingEngine.compute(standard);

      expect(result.machineKwh, 0);
      expect(result.machineElectricityCost, 0);
      expect(result.accessoryCost, 0);
      expect(result.waterCost, 0);
      expect(result.transportAndOtherCost, 0);
    });
  });

  test('le brouillon conserve machines et accessoires en JSON', () {
    final restored = EntrepreneurPricingDraft.fromJson(_draft().toJson());

    expect(restored.machines, hasLength(1));
    expect(restored.machines.single.name, 'Four');
    expect(restored.accessories, hasLength(1));
    expect(restored.accessories.single.name, 'Filtre');
    expect(restored.accessories.single.costPerUnit, closeTo(3, 0.000001));
  });
}

EntrepreneurPricingDraft _draft() {
  return const EntrepreneurPricingDraft(
    projectName: 'Produit test',
    mode: EntrepreneurPricingMode.expert,
    expectedPriceTtc: 50,
    materials: 10,
    packaging: 1,
    consumables: 2,
    workMinutes: 60,
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
}