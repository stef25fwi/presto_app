import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/pricing_calculator_page.dart';

void main() {
  test('pricing engine computes direct, labour, fixed and selling costs', () {
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
    );

    final result = PricingEngine.compute(input);

    expect(result.coutDirect, closeTo(14.5, 0.001));
    expect(result.coutMainOeuvre, closeTo(18.75, 0.001));
    expect(result.chargesFixesUnitaires, closeTo(10, 0.001));
    expect(result.coutDeRevient, closeTo(43.25, 0.001));
    expect(result.prixMinimumRentable, greaterThan(result.coutDeRevient));
    expect(result.prixConseille, greaterThan(result.prixMinimumRentable));
  });

  test('pricing engine handles fixed fees, VAT and defensive clamps', () {
    const input = PricingInput(
      matieres: -5,
      emballage: 2,
      consommables: 3,
      tempsFabricationMin: -60,
      tauxHoraire: -20,
      chargesMensuelles: 100,
      volumeMensuel: 0,
      fraisVentePct: 2,
      fraisVenteFixe: 4,
      margePctSurCout: -1,
      tvaPct: 0.2,
    );

    final result = PricingEngine.compute(input);

    expect(result.coutDirect, closeTo(5, 0.001));
    expect(result.coutMainOeuvre, 0);
    expect(result.chargesFixesUnitaires, closeTo(100, 0.001));
    expect(result.prixMinimumRentable, greaterThan(100));
    expect(result.prixConseille, greaterThan(result.prixMinimumRentable));
  });

  test('market positioning covers missing, low, aligned and premium ranges', () {
    final missing = MarketPositioning.evaluate(
      price: 50,
      low: 0,
      mid: 0,
      high: 0,
    );
    expect(missing.label, 'Marché non renseigné');

    final low = MarketPositioning.evaluate(
      price: 20,
      low: 30,
      mid: 50,
      high: 70,
    );
    expect(low.label, 'Sous-évalué');

    final aligned = MarketPositioning.evaluate(
      price: 55,
      low: 30,
      mid: 50,
      high: 70,
    );
    expect(aligned.label, 'Aligné sur le marché!');

    final premium = MarketPositioning.evaluate(
      price: 90,
      low: 30,
      mid: 50,
      high: 70,
    );
    expect(premium.label, 'Positionnement Premium');
  });

  testWidgets('selects every pricing mode and opens the calculator form',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PrestoPriceCalculatorApp());

    expect(find.text('Calculatrice de Prix Artisan'), findsOneWidget);
    expect(find.text('Mode Express'), findsOneWidget);
    expect(find.text('Mode Standard'), findsOneWidget);
    expect(find.text('Mode Expert'), findsOneWidget);
    expect(find.text('Le plus rapide'), findsOneWidget);
    expect(find.text('Le plus équilibré'), findsOneWidget);
    expect(find.text('Le plus précis'), findsOneWidget);

    await tester.tap(find.text('Mode Standard'));
    await tester.pump();
    await tester.tap(find.text('Mode Expert'));
    await tester.pump();
    await tester.tap(find.text('Mode Express'));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Commencer'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    expect(find.text('Mode Express : Estimation Rapide'), findsOneWidget);
    expect(find.text('1. Coûts Matériels'), findsOneWidget);
    expect(find.text("2. Temps & Main d'oeuvre"), findsOneWidget);
  });

  testWidgets('edits form fields, uses presets and opens results',
      (tester) async {
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

    final fields = find.byType(TextField);
    expect(fields, findsAtLeastNWidgets(8));
    await tester.enterText(fields.at(0), '20,50');
    await tester.enterText(fields.at(1), '2');
    await tester.enterText(fields.at(2), '1');
    await tester.enterText(fields.at(3), '60');
    await tester.enterText(fields.at(5), '200');
    await tester.enterText(fields.at(6), '20');
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byTooltip('Presets'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Presets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('35 €/h (expert)'));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('4. Frais de Vente'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Frais de plateforme :'), findsOneWidget);

    final typeRow = find.ancestor(
      of: find.text('Type :'),
      matching: find.byType(Row),
    ).first;
    final fixedToggle = find.descendant(
      of: typeRow,
      matching: find.text('€'),
    );
    await tester.tap(fixedToggle.last);
    await tester.pump();
    expect(find.text('Frais fixes par vente :'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Voir mon Prix Conseillé'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Voir mon Prix Conseillé'));
    await tester.pumpAndSettle();

    expect(find.text('Résultats & Positionnement'), findsOneWidget);
    expect(find.text('Coût de revient :'), findsOneWidget);
    expect(find.text('Prix minimum rentable :'), findsOneWidget);
    expect(find.text('Prix conseillé :'), findsOneWidget);
    expect(find.text('Positionnement Marché'), findsOneWidget);
  });

  testWidgets('disables calculation when time is invalid then recovers',
      (tester) async {
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

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(3), '0');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Voir mon Prix Conseillé'),
      350,
      scrollable: find.byType(Scrollable).first,
    );

    final disabledInkWell = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Voir mon Prix Conseillé'),
        matching: find.byType(InkWell),
      ).first,
    );
    expect(disabledInkWell.onTap, isNull);

    await tester.enterText(fields.at(3), '30');
    await tester.pump();
    final enabledInkWell = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Voir mon Prix Conseillé'),
        matching: find.byType(InkWell),
      ).first,
    );
    expect(enabledInkWell.onTap, isNotNull);
  });
}
