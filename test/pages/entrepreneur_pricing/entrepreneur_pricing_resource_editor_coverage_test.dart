import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/entrepreneur_pricing/entrepreneur_pricing_models.dart';
import 'package:presto_app/pages/entrepreneur_pricing/entrepreneur_pricing_resource_editor.dart';

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
  testWidgets('renders empty resources and zero summaries', (tester) async {
    await tester.pumpWidget(
      _host(
        ProductionResourcesEditor(
          machines: const [],
          accessories: const [],
          electricityRate: 0.25,
          onMachinesChanged: (_) {},
          onAccessoriesChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Machines utilisées'), findsOneWidget);
    expect(find.text('Accessoires et fournitures'), findsOneWidget);
    expect(
      find.text(
        'Ajoute chaque machine pour calculer sa consommation électrique exacte.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Ajoute les accessoires consommés : lames, buses, gants, mèches, filtres…',
      ),
      findsOneWidget,
    );
    expect(find.text('0,0000 kWh par unité • 0,00 €'), findsOneWidget);
    expect(find.text('0,00 € par unité'), findsOneWidget);
  });

  testWidgets('computes summaries and deletes the selected machine only',
      (tester) async {
    List<ProductionMachineUsage>? emitted;
    const machines = [
      ProductionMachineUsage(
        name: 'Four',
        watts: 1200,
        minutesPerUnit: 30,
        quantity: 2,
      ),
      ProductionMachineUsage(
        name: 'Ponceuse',
        watts: 600,
        minutesPerUnit: 15,
        quantity: 1,
      ),
    ];

    await tester.pumpWidget(
      _host(
        ProductionResourcesEditor(
          machines: machines,
          accessories: const [],
          electricityRate: 0.25,
          onMachinesChanged: (value) => emitted = value,
          onAccessoriesChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Four'), findsOneWidget);
    expect(find.text('Ponceuse'), findsOneWidget);
    expect(find.text('1,3500 kWh par unité • 0,34 €'), findsOneWidget);

    final actions = find.byTooltip('Actions');
    expect(actions, findsNWidgets(2));
    await tester.tap(actions.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(emitted, isNotNull);
    expect(emitted, hasLength(1));
    expect(emitted!.single.name, 'Ponceuse');
    expect(identical(emitted, machines), isFalse);
  });

  testWidgets('computes accessory total and deletes the selected accessory only',
      (tester) async {
    List<ProductionAccessoryUsage>? emitted;
    const accessories = [
      ProductionAccessoryUsage(
        name: 'Boîte',
        quantityPerUnit: 2,
        unitPrice: 1.5,
      ),
      ProductionAccessoryUsage(
        name: 'Filtre',
        quantityPerUnit: 0.5,
        unitPrice: 4,
      ),
    ];

    await tester.pumpWidget(
      _host(
        ProductionResourcesEditor(
          machines: const [],
          accessories: accessories,
          electricityRate: 0.25,
          onMachinesChanged: (_) {},
          onAccessoriesChanged: (value) => emitted = value,
        ),
      ),
    );

    expect(find.text('Boîte'), findsOneWidget);
    expect(find.text('Filtre'), findsOneWidget);
    expect(find.text('5,00 € par unité'), findsOneWidget);

    final actions = find.byTooltip('Actions');
    expect(actions, findsNWidgets(2));
    await tester.tap(actions.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(emitted, isNotNull);
    expect(emitted, hasLength(1));
    expect(emitted!.single.name, 'Boîte');
    expect(identical(emitted, accessories), isFalse);
  });

  testWidgets('summary calculations clamp negative machine inputs through models',
      (tester) async {
    const machine = ProductionMachineUsage(
      name: 'Valeurs négatives',
      watts: -1000,
      minutesPerUnit: -30,
      quantity: -2,
    );
    const accessory = ProductionAccessoryUsage(
      name: 'Accessoire négatif',
      quantityPerUnit: -2,
      unitPrice: 3,
    );

    await tester.pumpWidget(
      _host(
        ProductionResourcesEditor(
          machines: const [machine],
          accessories: const [accessory],
          electricityRate: -1,
          onMachinesChanged: (_) {},
          onAccessoriesChanged: (_) {},
        ),
      ),
    );

    expect(find.text('0,0000 kWh par unité • 0,00 €'), findsOneWidget);
    expect(find.text('0,00 € par unité'), findsOneWidget);
  });
}
