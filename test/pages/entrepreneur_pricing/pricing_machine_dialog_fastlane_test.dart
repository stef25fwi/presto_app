import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/entrepreneur_pricing/entrepreneur_pricing_machine_dialog.dart';
import 'package:presto_app/pages/entrepreneur_pricing/entrepreneur_pricing_models.dart';

void main() {
  Finder numberField(String key) => find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(TextField),
      );

  Future<void> pumpLauncher(
    WidgetTester tester, {
    ProductionMachineUsage? initialValue,
    required void Function(ProductionMachineUsage? value) onCompleted,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                final value = await showProductionMachineDialog(
                  context,
                  initialValue: initialValue,
                );
                onCompleted(value);
              },
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('ajoute une machine avec nombres décimaux normalisés',
      (tester) async {
    ProductionMachineUsage? result;
    await pumpLauncher(tester, onCompleted: (value) => result = value);

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Ajouter une machine'), findsOneWidget);
    expect(find.text('Nom de la machine'), findsOneWidget);
    expect(find.text('Puissance'), findsOneWidget);
    expect(find.text('Temps d’utilisation par unité'), findsOneWidget);
    expect(find.text('Nombre de machines identiques'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('machine-name')),
      'Four professionnel',
    );
    await tester.enterText(
      numberField('machine-watts'),
      '1 250,5',
    );
    await tester.enterText(
      numberField('machine-minutes'),
      '12,5',
    );
    await tester.enterText(
      numberField('machine-quantity'),
      '2',
    );

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Four professionnel');
    expect(result!.watts, 1250.5);
    expect(result!.minutesPerUnit, 12.5);
    expect(result!.quantity, 2);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('refuse les valeurs invalides et conserve le dialogue',
      (tester) async {
    ProductionMachineUsage? result;
    await pumpLauncher(tester, onCompleted: (value) => result = value);

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('machine-name')),
      '   ',
    );
    await tester.enterText(
      numberField('machine-watts'),
      '0',
    );
    await tester.enterText(
      numberField('machine-minutes'),
      'abc',
    );
    await tester.enterText(
      numberField('machine-quantity'),
      '-1',
    );

    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(
      find.text(
        'Renseigne un nom, une puissance, une durée et une quantité valides.',
      ),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('préremplit une machine existante puis permet l annulation',
      (tester) async {
    ProductionMachineUsage? result = const ProductionMachineUsage(
      name: 'sentinel',
      watts: 1,
      minutesPerUnit: 1,
    );
    const initial = ProductionMachineUsage(
      name: 'Découpeuse',
      watts: 800,
      minutesPerUnit: 7.5,
      quantity: 3,
    );
    await pumpLauncher(
      tester,
      initialValue: initial,
      onCompleted: (value) => result = value,
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier la machine'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('machine-name')))
          .controller!
          .text,
      'Découpeuse',
    );
    expect(
      tester.widget<TextField>(numberField('machine-watts')).controller!.text,
      '800',
    );
    expect(
      tester.widget<TextField>(numberField('machine-minutes')).controller!.text,
      '7.5',
    );
    expect(
      tester.widget<TextField>(numberField('machine-quantity')).controller!.text,
      '3',
    );

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
