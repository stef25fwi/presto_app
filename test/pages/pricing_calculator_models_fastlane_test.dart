import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/pricing_calculator_page.dart';

void main() {
  test('PricingInput JSON normalizes malformed values and minimum volume', () {
    final input = PricingInput.fromJson(<String, dynamic>{
      'matieres': '12.5',
      'emballage': 2,
      'consommables': null,
      'tempsFabricationMin': '45',
      'tauxHoraire': '20',
      'chargesMensuelles': '300',
      'volumeMensuel': 0,
      'fraisVentePct': '0.12',
      'fraisVenteFixe': 1,
      'margePctSurCout': '0.35',
      'tvaPct': '0.2',
      'regionCode': 'GP',
    });

    expect(input.matieres, 12.5);
    expect(input.volumeMensuel, 1);
    expect(input.consommables, 0);
    expect(input.regionCode, 'GP');
    expect(PricingInput.fromJson(input.toJson()).toJson(), input.toJson());
  });

  test('PricingEngine includes utilities, transport and amortization', () {
    const input = PricingInput(
      matieres: 10,
      emballage: 2,
      consommables: 1,
      tempsFabricationMin: 60,
      tauxHoraire: 20,
      chargesMensuelles: 100,
      volumeMensuel: 10,
      fraisVentePct: 0.1,
      fraisVenteFixe: 1,
      margePctSurCout: 0.25,
      tvaPct: 0.2,
      prixVenteTtcEnvisage: 80,
      materielAAmortir: 100,
      amortissementParUnite: 5,
      electriciteKwhParUnite: 2,
      tarifElectriciteKwh: 0.5,
      eauM3ParUnite: 1,
      tarifEauM3: 2,
      transportParUnite: 3,
      autresCoutsParUnite: 4,
    );

    final result = PricingEngine.compute(input);
    expect(result.coutEnergieEau, 3);
    expect(result.coutTransportAutres, 7);
    expect(result.amortissementUnitaire, 5);
    expect(result.unitesPourAmortir, 20);
    expect(result.prixTTC, greaterThan(result.prixMinimumRentableTtc));
    expect(PricingResult.fromJson(result.toJson()).toJson(), result.toJson());
  });

  test('scenario clamps zero volume to one deterministic unit', () {
    const input = PricingInput(
      matieres: 5,
      emballage: 0,
      consommables: 0,
      tempsFabricationMin: 0,
      tauxHoraire: 0,
      chargesMensuelles: 0,
      volumeMensuel: 1,
      fraisVentePct: 2,
      fraisVenteFixe: 0,
      margePctSurCout: 0,
      tvaPct: 0,
    );

    final scenario = PricingEngine.computeScenario(
      input,
      name: 'Prudent',
      volume: 0,
    );
    expect(scenario.name, 'Prudent');
    expect(scenario.volume, 1);
    expect(scenario.chiffreAffairesTtc.isFinite, isTrue);
    expect(scenario.beneficeParUnite.isFinite, isTrue);
  });
}
