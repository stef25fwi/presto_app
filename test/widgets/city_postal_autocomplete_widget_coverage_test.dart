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
    final withoutPostalCode = CityEntry.fromJson(<String, dynamic>{
      'name': 'Ville test',
      'dept': '99',
    });

    expect(paris.name, 'PARIS 01');
    expect(paris.dept, '75');
    expect(paris.cps, <String>['75001']);
    expect(paris.displayName, 'Paris 1er arrondissement');
    expect(standard.displayName, 'Pau');
    expect(withoutPostalCode.cps, isEmpty);
  });

  test('CityPostalService couvre recherche, filtres CP et résolution locale', () async {
    final service = CityPostalService();

    await service.init();
    // init() doit être idempotent et ne pas recharger les assets.
    await service.init();

    expect(service.search(''), isEmpty);

    final paris = service.search('paris', limit: 5);
    expect(paris, isNotEmpty);
    expect(paris.length, lessThanOrEqualTo(5));
    expect(
      paris.every((entry) => entry.name.toLowerCase().contains('paris')),
      isTrue,
    );

    // Exerce la seconde passe `contains` plutôt que `startsWith`.
    final containsParis = service.search('aris', limit: 3);
    expect(containsParis, isNotEmpty);
    expect(containsParis.length, lessThanOrEqualTo(3));

    final first = paris.first;
    expect(first.cps, isNotEmpty);
    final cp = first.cps.first;

    final resolved = service.findByPostalCode(cp);
    expect(resolved, isNotNull);
    expect(resolved!.cps, contains(cp));

    expect(
      service.findByPostalCode(cp, dept: first.dept)?.dept,
      first.dept,
    );
    expect(service.findByPostalCode(cp, dept: 'XX'), isNull);
    expect(service.findByPostalCode(''), isNull);

    final sameDepartment = service.search(
      'paris',
      cpHint: cp,
      limit: 10,
    );
    expect(sameDepartment, isNotEmpty);
    expect(sameDepartment.every((entry) => entry.dept == first.dept), isTrue);

    // Exerce les règles départementales DROM/COM et Corse sans appel réseau.
    expect(service.search('paris', cpHint: '97100'), isEmpty);
    expect(service.search('paris', cpHint: '20000'), isEmpty);
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
