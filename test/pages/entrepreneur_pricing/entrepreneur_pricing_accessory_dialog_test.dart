import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/entrepreneur_pricing/entrepreneur_pricing_accessory_dialog.dart';
import 'package:presto_app/pages/entrepreneur_pricing/entrepreneur_pricing_models.dart';

Widget _harness({
  ProductionAccessoryUsage? initialValue,
  required ValueChanged<ProductionAccessoryUsage?> onResult,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            onResult(
              await showProductionAccessoryDialog(
                context,
                initialValue: initialValue,
              ),
            );
          },
          child: const Text('Ouvrir'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('affiche les valeurs par défaut puis annule', (tester) async {
    ProductionAccessoryUsage? result;
    var completed = false;

    await tester.pumpWidget(
      _harness(
        onResult: (value) {
          result = value;
          completed = true;
        },
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Ajouter un accessoire'), findsOneWidget);
    expect(find.text('Nom de l’accessoire'), findsOneWidget);
    expect(find.text('Quantité utilisée par unité'), findsOneWidget);
    expect(find.text('Prix unitaire'), findsOneWidget);

    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('accessory-name')))
          .controller!
          .text,
      'Accessoire',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('accessory-quantity')))
          .controller!
          .text,
      '1',
    );
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('accessory-price')))
          .controller!
          .text,
      '1',
    );

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
    expect(find.text('Ajouter un accessoire'), findsNothing);
  });

  testWidgets('modifie et normalise les nombres décimaux', (tester) async {
    ProductionAccessoryUsage? result;

    await tester.pumpWidget(
      _harness(
        initialValue: const ProductionAccessoryUsage(
          name: 'Ruban',
          quantityPerUnit: 2.5,
          unitPrice: 4,
        ),
        onResult: (value) => result = value,
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier l’accessoire'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('accessory-name')))
          .controller!
          .text,
      'Ruban',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('accessory-quantity')))
          .controller!
          .text,
      '2.5',
    );
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('accessory-price')))
          .controller!
          .text,
      '4',
    );

    await tester.enterText(
      find.byKey(const ValueKey('accessory-name')),
      '  Sachet kraft  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('accessory-quantity')),
      ' 1,5 ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('accessory-price')),
      ' 0,75 ',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Sachet kraft');
    expect(result!.quantityPerUnit, 1.5);
    expect(result!.unitPrice, 0.75);
    expect(find.text('Modifier l’accessoire'), findsNothing);
  });

  testWidgets('refuse les valeurs invalides puis accepte la correction', (
    tester,
  ) async {
    ProductionAccessoryUsage? result;

    await tester.pumpWidget(
      _harness(onResult: (value) => result = value),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('accessory-name')),
      '   ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('accessory-quantity')),
      'abc',
    );
    await tester.enterText(
      find.byKey(const ValueKey('accessory-price')),
      '-1',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(
      find.text('Renseigne un nom, une quantité et un prix valides.'),
      findsOneWidget,
    );
    expect(find.text('Ajouter un accessoire'), findsOneWidget);
    expect(result, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('accessory-name')),
      'Boîte',
    );
    await tester.enterText(
      find.byKey(const ValueKey('accessory-quantity')),
      '2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('accessory-price')),
      '0',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Boîte');
    expect(result!.quantityPerUnit, 2);
    expect(result!.unitPrice, 0);
  });
}
