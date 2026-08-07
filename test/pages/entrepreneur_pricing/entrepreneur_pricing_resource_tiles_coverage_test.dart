import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/entrepreneur_pricing/entrepreneur_pricing_models.dart';
import 'package:presto_app/pages/entrepreneur_pricing/entrepreneur_pricing_resource_tiles.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('resource formatting', () {
    test('formats finite monetary and numeric values with comma decimals', () {
      expect(resourceMoney(12.345), '12,35');
      expect(resourceNumber(42.5, 1), '42,5');
      expect(resourceNumber(7, 0), '7');
    });

    test('normalizes non-finite values to zero', () {
      expect(resourceNumber(double.infinity, 2), '0,00');
      expect(resourceNumber(double.negativeInfinity, 1), '0,0');
      expect(resourceMoney(double.nan), '0,00');
    });
  });

  testWidgets('ResourceHeader renders copy and dispatches its action', (tester) async {
    var pressed = 0;

    await tester.pumpWidget(
      _host(
        ResourceHeader(
          icon: Icons.bolt,
          title: 'Machines',
          subtitle: 'Équipements électriques',
          actionLabel: 'Ajouter une machine',
          onPressed: () => pressed++,
        ),
      ),
    );

    expect(find.byIcon(Icons.bolt), findsOneWidget);
    expect(find.text('Machines'), findsOneWidget);
    expect(find.text('Équipements électriques'), findsOneWidget);
    expect(find.text('Ajouter une machine'), findsOneWidget);

    await tester.tap(find.text('Ajouter une machine'));
    await tester.pump();
    expect(pressed, 1);
  });

  testWidgets('MachineResourceTile renders computed energy and handles both menu actions',
      (tester) async {
    var editCount = 0;
    var deleteCount = 0;
    const machine = ProductionMachineUsage(
      name: 'Four atelier',
      watts: 1200,
      minutesPerUnit: 30,
      quantity: 2,
    );

    await tester.pumpWidget(
      _host(
        MachineResourceTile(
          machine: machine,
          electricityRate: 0.25,
          onEdit: () => editCount++,
          onDelete: () => deleteCount++,
        ),
      ),
    );

    expect(find.text('Four atelier'), findsOneWidget);
    expect(find.text('1200 W • 30,0 min • ×2'), findsOneWidget);
    expect(find.text('1,0000 kWh\n0,25 €'), findsOneWidget);
    expect(find.byIcon(Icons.precision_manufacturing_outlined), findsOneWidget);

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(editCount, 1);
    expect(deleteCount, 0);

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(editCount, 1);
    expect(deleteCount, 1);
  });

  testWidgets('AccessoryResourceTile renders unit and total cost and menu actions',
      (tester) async {
    var edited = false;
    var deleted = false;
    const accessory = ProductionAccessoryUsage(
      name: 'Boîte carton',
      quantityPerUnit: 2.5,
      unitPrice: 1.2,
    );

    await tester.pumpWidget(
      _host(
        AccessoryResourceTile(
          accessory: accessory,
          onEdit: () => edited = true,
          onDelete: () => deleted = true,
        ),
      ),
    );

    expect(find.text('Boîte carton'), findsOneWidget);
    expect(find.text('2,50 × 1,20 €'), findsOneWidget);
    expect(find.text('3,00 €'), findsOneWidget);
    expect(find.byIcon(Icons.construction_outlined), findsOneWidget);

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(edited, isTrue);
    expect(deleted, isFalse);

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });

  testWidgets('EmptyResource and ResourceSummaryPill render their visual states',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            EmptyResource(text: 'Aucune machine ajoutée'),
            SizedBox(height: 12),
            ResourceSummaryPill(
              icon: Icons.savings_outlined,
              text: 'Coût ressources : 8,40 €',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Aucune machine ajoutée'), findsOneWidget);
    expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
    expect(find.text('Coût ressources : 8,40 €'), findsOneWidget);
  });
}
