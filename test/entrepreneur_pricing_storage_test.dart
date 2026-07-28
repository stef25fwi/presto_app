import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/entrepreneur_pricing/entrepreneur_pricing_models.dart';
import 'package:presto_app/pages/entrepreneur_pricing/entrepreneur_pricing_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('sauvegarde puis relit les détails exacts de production', () async {
    final draft = _draft();
    final calculation = EntrepreneurPricingEngine.compute(draft);
    final record = EntrepreneurPricingRecord(
      id: 'record-1',
      createdAt: DateTime(2026, 7, 28, 15, 30),
      draft: draft,
      calculation: calculation,
    );

    await EntrepreneurPricingStorage.save(record);
    final loaded = await EntrepreneurPricingStorage.load();

    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'record-1');
    expect(loaded.single.draft.machines.single.name, 'Four');
    expect(loaded.single.draft.accessories.single.name, 'Filtre');
    expect(
      loaded.single.calculation.machineElectricityCost,
      closeTo(calculation.machineElectricityCost, 0.000001),
    );
  });

  test('ignore une sauvegarde dont le checksum est altéré', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      EntrepreneurPricingStorage.storageKey:
          '[{"version":3,"checksum":"00000000","payload":{"id":"bad"}}]',
    });

    expect(await EntrepreneurPricingStorage.load(), isEmpty);
  });

  test('supprime puis vérifie l’absence du calcul', () async {
    final draft = _draft();
    final record = EntrepreneurPricingRecord(
      id: 'record-1',
      createdAt: DateTime(2026, 7, 28),
      draft: draft,
      calculation: EntrepreneurPricingEngine.compute(draft),
    );
    await EntrepreneurPricingStorage.save(record);

    await EntrepreneurPricingStorage.delete(record.id);

    expect(await EntrepreneurPricingStorage.load(), isEmpty);
  });
}

EntrepreneurPricingDraft _draft() {
  return const EntrepreneurPricingDraft(
    projectName: 'Test',
    mode: EntrepreneurPricingMode.expert,
    expectedPriceTtc: 50,
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
}