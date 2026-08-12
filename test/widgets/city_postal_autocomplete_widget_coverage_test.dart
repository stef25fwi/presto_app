import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/city_postal_autocomplete_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CityEntry parse les champs et formate les arrondissements de Paris', () {
    final paris = CityEntry.fromJson(<String, dynamic>{
      'name': 'PARIS 01',
      'dept': '75',
      'cps': <String>['75001'],
    });
    final standard = CityEntry.fromJson(<String, dynamic>{
      'name': 'Pau',
      'dept': '64',
      'cps': <String>['64000'],
    });

    expect(paris.name, 'PARIS 01');
    expect(paris.dept, '75');
    expect(paris.cps, <String>['75001']);
    expect(paris.displayName, 'Paris 1er arrondissement');
    expect(standard.displayName, 'Pau');
  });

  late TextEditingController cityController;
  late TextEditingController postalCodeController;
  CityEntry? selectedEntry;

  setUp(() {
    cityController = TextEditingController();
    postalCodeController = TextEditingController();
    selectedEntry = null;
  });

  tearDown(() {
    cityController.dispose();
    postalCodeController.dispose();
  });

  Future<void> pumpField(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: CityPostalAutocompleteField(
              cityController: cityController,
              postalCodeController: postalCodeController,
              decoration: const InputDecoration(labelText: 'Ville'),
              onSelected: (entry) => selectedEntry = entry,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'recherche localement Paris avec deux caractères puis sélectionne une suggestion',
    (tester) async {
      await pumpField(tester);

      final cityField = find.byType(TextFormField);
      expect(cityField, findsOneWidget);
      await tester.tap(cityField);
      await tester.enterText(cityField, 'Pa');

      // Deux caractères : parcours local uniquement, sans Geo API.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      final suggestions = find.byType(ListTile);
      expect(suggestions, findsWidgets);
      await tester.tap(suggestions.first);
      await tester.pump();
      await tester.pumpAndSettle();

      // Une commune peut proposer plusieurs CP : terminer le choix réel si
      // le widget ouvre sa feuille modale.
      if (find.textContaining('Choisir le code postal').evaluate().isNotEmpty) {
        final postalOptions = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              RegExp(r'^\d{5}$').hasMatch(widget.data?.trim() ?? ''),
        );
        expect(postalOptions, findsWidgets);
        await tester.tap(postalOptions.first);
        await tester.pumpAndSettle();
      }

      expect(cityController.text.trim(), isNotEmpty);
      expect(postalCodeController.text, matches(RegExp(r'^\d{5}$')));
      expect(selectedEntry, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'une saisie ville courte et un CP incomplet restent purement locaux',
    (tester) async {
      await pumpField(tester);

      final cityField = find.byType(TextFormField);
      await tester.tap(cityField);
      await tester.enterText(cityField, 'Xx');
      postalCodeController.text = '9719';

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(cityController.text, 'Xx');
      expect(postalCodeController.text, '9719');
      expect(selectedEntry, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dispose annule les deux debounces encore actifs', (tester) async {
    await pumpField(tester);

    final cityField = find.byType(TextFormField);
    await tester.tap(cityField);
    await tester.enterText(cityField, 'Pa');
    postalCodeController.text = '9719';

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });
}
