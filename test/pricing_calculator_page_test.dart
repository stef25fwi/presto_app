import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/pricing_calculator_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const standardInput = PricingInput(
    matieres: 12.5,
    emballage: 1.2,
    consommables: 0.8,
    tempsFabricationMin: 45,
    tauxHoraire: 25,
    chargesMensuelles: 300,
    volumeMensuel: 30,
    fraisVentePct: 0.12,
    fraisVenteFixe: 0,
    margePctSurCout: 0.35,
    tvaPct: 0,
    prixVenteTtcEnvisage: 50,
    materielAAmortir: 300,
    amortissementParUnite: 10,
  );

  test('standard engine calculates cost, amortization and loss warning', () {
    final result = PricingEngine.compute(standardInput);

    expect(result.coutDirect, closeTo(14.5, 0.001));
    expect(result.coutEnergieEau, 0);
    expect(result.coutTransportAutres, 0);
    expect(result.coutMainOeuvre, closeTo(18.75, 0.001));
    expect(result.chargeFixeUnitaire, closeTo(10, 0.001));
    expect(result.amortissementUnitaire, closeTo(10, 0.001));
    expect(result.coutDeRevient, closeTo(53.25, 0.001));
    expect(result.prixMinimumRentable, closeTo(60.511, 0.001));
    expect(result.prixTTC, closeTo(81.690, 0.001));
    expect(result.margeUnitaireEnvisagee, closeTo(-9.25, 0.001));
    expect(result.prixEnvisageRentable, isFalse);
    expect(result.unitesPourAmortir, 30);
    expect(result.seuilRentabiliteUnites, 400);
  });

  test('expert engine adds energy, transport, VAT and break-even analysis', () {
    const input = PricingInput(
      matieres: 5,
      emballage: 2,
      consommables: 3,
      tempsFabricationMin: 60,
      tauxHoraire: 20,
      chargesMensuelles: 100,
      volumeMensuel: 10,
      fraisVentePct: 0,
      fraisVenteFixe: 2,
      margePctSurCout: 0.2,
      tvaPct: 0.2,
      prixVenteTtcEnvisage: 72,
      materielAAmortir: 500,
      amortissementParUnite: 5,
      electriciteKwhParUnite: 2,
      tarifElectriciteKwh: 0.25,
      eauM3ParUnite: 0.1,
      tarifEauM3: 4,
      transportParUnite: 3,
      autresCoutsParUnite: 1,
      regionCode: '971',
    );

    final result = PricingEngine.compute(input);
    final scenario = PricingEngine.computeScenario(
      input,
      name: 'Prudent',
      volume: 5,
    );

    expect(result.coutEnergieEau, closeTo(0.9, 0.001));
    expect(result.coutTransportAutres, closeTo(4, 0.001));
    expect(result.coutDirect, closeTo(14.9, 0.001));
    expect(result.coutDeRevient, closeTo(49.9, 0.001));
    expect(result.prixMinimumRentableTtc, closeTo(62.28, 0.001));
    expect(result.prixTTC, closeTo(74.256, 0.001));
    expect(result.margeUnitaireEnvisagee, closeTo(8.1, 0.001));
    expect(result.prixEnvisageRentable, isTrue);
    expect(result.unitesPourAmortir, 100);
    expect(result.seuilRentabiliteUnites, 6);
    expect(scenario.chiffreAffairesTtc, closeTo(360, 0.001));
    expect(scenario.beneficeMensuel, closeTo(-9.5, 0.001));
  });

  test('pricing engine handles defensive percentage fee clamps', () {
    const input = PricingInput(
      matieres: 5,
      emballage: 2,
      consommables: 3,
      tempsFabricationMin: 0,
      tauxHoraire: 20,
      chargesMensuelles: 100,
      volumeMensuel: 0,
      fraisVentePct: 2,
      fraisVenteFixe: 4,
      margePctSurCout: 0,
      tvaPct: 0.2,
    );

    final result = PricingEngine.compute(input);

    expect(result.coutDirect, closeTo(10, 0.001));
    expect(result.chargeFixeUnitaire, closeTo(100, 0.001));
    expect(result.prixMinimumRentable, closeTo(114000, 0.1));
    expect(result.prixTTC, closeTo(136800, 0.1));
  });

  test('market positioning covers missing, low, aligned and premium ranges', () {
    expect(
      MarketPositioning.evaluate(price: 50, low: 0, mid: 0, high: 0).label,
      'Marché non renseigné',
    );
    expect(
      MarketPositioning.evaluate(price: 50, low: 60, mid: 50, high: 40).label,
      'Marché non renseigné',
    );
    expect(
      MarketPositioning.evaluate(price: 20, low: 30, mid: 50, high: 70).label,
      'Sous-évalué',
    );
    expect(
      MarketPositioning.evaluate(price: 55, low: 30, mid: 50, high: 70).label,
      'Aligné sur le marché!',
    );
    expect(
      MarketPositioning.evaluate(price: 90, low: 30, mid: 50, high: 70).label,
      'Positionnement Premium',
    );
  });

  test('input and result remain serializable for expert history', () {
    final result = PricingEngine.compute(standardInput);
    final restoredInput = PricingInput.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(standardInput.toJson())) as Map,
      ),
    );
    final restoredResult = PricingResult.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(result.toJson())) as Map,
      ),
    );

    expect(restoredInput.materielAAmortir, 300);
    expect(restoredInput.prixVenteTtcEnvisage, 50);
    expect(restoredResult.unitesPourAmortir, 30);
    expect(restoredResult.prixTTC, closeTo(result.prixTTC, 0.001));
  });

  test('expert projects are saved and removed from local history', () async {
    SharedPreferences.setMockInitialValues({});
    final result = PricingEngine.compute(standardInput);
    final record = PricingProjectRecord(
      id: 'one',
      createdAt: DateTime(2026, 7, 28, 12),
      name: 'Prestation test',
      mode: PricingMode.expert,
      input: standardInput,
      result: result,
      marketLow: 40,
      marketMid: 60,
      marketHigh: 80,
      volumePrudent: 10,
      volumeHaut: 50,
    );

    await PricingProjectStorage.save(record);
    final stored = await PricingProjectStorage.load();
    expect(stored, hasLength(1));
    expect(stored.single.name, 'Prestation test');
    expect(stored.single.mode, PricingMode.expert);

    await PricingProjectStorage.delete('one');
    expect(await PricingProjectStorage.load(), isEmpty);
  });

  test('expert regional tariffs load from the documented Firestore paths',
      () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('tarifs_electricite').doc('971').set({
      'prixKwh': 0.31,
      'updatedAt': DateTime(2026, 7, 1),
    });
    await firestore.collection('tarifs_eau').doc('971').set({
      'prixM3': 5.2,
      'updatedAt': DateTime(2026, 7, 2),
    });

    final tariffs = await PricingRegionalTariffRepository(
      firestore: firestore,
    ).load('971');

    expect(tariffs, isNotNull);
    expect(tariffs!.electricityPerKwh, closeTo(0.31, 0.001));
    expect(tariffs.waterPerM3, closeTo(5.2, 0.001));
    expect(tariffs.updatedAt, DateTime(2026, 7, 2));
  });

  test('expert PDF export produces a real PDF document', () async {
    final result = PricingEngine.compute(standardInput);
    final bytes = await PricingPdfExporter.build(
      projectName: 'Prestation test',
      input: standardInput,
      result: result,
      scenarios: [
        PricingEngine.computeScenario(
          standardInput,
          name: 'Cible',
          volume: 30,
        ),
      ],
      market: MarketPositioning.evaluate(
        price: result.prixTTC,
        low: 40,
        mid: 60,
        high: 90,
      ),
    );

    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  testWidgets('offers exactly Standard and Expert modes', (tester) async {
    await _setLargeViewport(tester);
    await tester.pumpWidget(const PrestoPriceCalculatorApp());

    expect(find.text("Calculatrice de l'entrepreneur"), findsOneWidget);
    expect(find.text('Mode Standard'), findsOneWidget);
    expect(find.text('Mode Expert'), findsOneWidget);
    expect(find.text('Mode Express'), findsNothing);
    expect(find.text('Recommandé'), findsOneWidget);
    expect(find.text('Le plus précis'), findsOneWidget);
  });

  testWidgets('Standard shows guided fields without expert-only sections',
      (tester) async {
    await _openMode(tester, PricingMode.standard);

    expect(find.text('Mode Standard'), findsOneWidget);
    expect(find.text('2. Coûts directs par unité'), findsOneWidget);
    expect(find.text('5. Amortissement du matériel'), findsOneWidget);
    expect(find.text('6. Coûts avancés et tarifs régionaux'), findsNothing);
    expect(find.text('8. Analyse du marché'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Calculer mon prix conseillé'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Calculer mon prix conseillé'));
    await tester.pumpAndSettle();

    expect(find.text('Résultats Standard'), findsOneWidget);
    expect(find.text('Amortissement & seuil'), findsOneWidget);
    expect(find.text('Positionnement Marché'), findsNothing);
    expect(find.text('Simulation mensuelle'), findsNothing);
    expect(find.text('Exporter en PDF'), findsNothing);
  });

  testWidgets('Expert shows advanced inputs, market, scenarios and actions',
      (tester) async {
    await _openMode(tester, PricingMode.expert);

    expect(find.text('Mode Expert'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('6. Coûts avancés et tarifs régionaux'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Territoire tarifaire'), findsOneWidget);
    expect(find.text('Électricité / unité :'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('8. Analyse du marché'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('9. Scénarios de volume'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Lancer mon analyse experte'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Lancer mon analyse experte'));
    await tester.pumpAndSettle();

    expect(find.text('Analyse experte'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Positionnement Marché'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Décomposition experte des coûts'), findsOneWidget);
    expect(find.text('Simulation mensuelle'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Exporter en PDF'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sauvegarder cette analyse'), findsOneWidget);
  });

  testWidgets('calculation is disabled when duration is invalid', (tester) async {
    await _openMode(tester, PricingMode.standard);

    await tester.scrollUntilVisible(
      find.text('3. Temps & main-d’œuvre'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    final durationRow = find.ancestor(
      of: find.text('Temps par unité :'),
      matching: find.byType(Row),
    );
    final durationField = find.descendant(
      of: durationRow,
      matching: find.byType(TextField),
    );
    await tester.enterText(durationField, '0');
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Calculer mon prix conseillé'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    final disabledInkWell = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Calculer mon prix conseillé'),
        matching: find.byType(InkWell),
      ).first,
    );
    expect(disabledInkWell.onTap, isNull);
  });
}

Future<void> _setLargeViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openMode(
  WidgetTester tester,
  PricingMode mode,
) async {
  await _setLargeViewport(tester);
  await tester.pumpWidget(const PrestoPriceCalculatorApp());
  if (mode == PricingMode.expert) {
    await tester.tap(find.text('Mode Expert'));
    await tester.pump();
  }
  await tester.scrollUntilVisible(
    find.text('Commencer'),
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Commencer'));
  await tester.pumpAndSettle();
}
