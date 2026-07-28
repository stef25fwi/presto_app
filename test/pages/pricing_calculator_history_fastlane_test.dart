import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/pricing_calculator_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const input = PricingInput(
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

  Future<void> openHistory(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PrestoPriceCalculatorApp());
    await tester.tap(find.text('Mes calculs enregistrés'));
    await tester.pumpAndSettle();
  }

  testWidgets('affiche un état vide quand aucun calcul n est sauvegardé',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await openHistory(tester);

    expect(find.text('Mes calculs'), findsOneWidget);
    expect(find.text('Aucun calcul enregistré'), findsOneWidget);
    expect(
      find.text('Les analyses Expert sauvegardées apparaîtront ici.'),
      findsOneWidget,
    );
  });

  testWidgets('ouvre puis supprime un calcul Expert sauvegardé', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final result = PricingEngine.compute(input);
    await PricingProjectStorage.save(
      PricingProjectRecord(
        id: 'history-one',
        createdAt: DateTime(2026, 7, 28, 12),
        name: 'Prestation historique',
        mode: PricingMode.expert,
        input: input,
        result: result,
        marketLow: 40,
        marketMid: 60,
        marketHigh: 80,
        volumePrudent: 10,
        volumeHaut: 50,
      ),
    );

    await openHistory(tester);

    expect(find.text('Prestation historique'), findsOneWidget);
    expect(find.textContaining('Expert'), findsWidgets);
    expect(find.textContaining('Prix conseillé'), findsOneWidget);

    await tester.tap(find.text('Prestation historique'));
    await tester.pumpAndSettle();
    expect(find.text('Analyse experte'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('Aucun calcul enregistré'), findsOneWidget);
    expect(await PricingProjectStorage.load(), isEmpty);
  });
}
