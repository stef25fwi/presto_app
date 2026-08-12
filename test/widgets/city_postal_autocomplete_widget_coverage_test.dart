import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/city_postal_autocomplete_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Autocomplete<CityEntry> autocomplete(WidgetTester tester) =>
      tester.widget<Autocomplete<CityEntry>>(
        find.byType(Autocomplete<CityEntry>),
      );

  testWidgets(
    'recherche localement avec deux caractères puis applique une suggestion',
    (tester) async {
      await pumpField(tester);

      final cityField = find.byType(TextFormField);
      expect(cityField, findsOneWidget);
      await tester.tap(cityField);
      await tester.enterText(cityField, 'Go');

      // Deux caractères restent sous le seuil Geo API : le parcours est
      // entièrement local et déterministe via cities_compact.json.
      await tester.pump(const Duration(milliseconds: 281));
      await tester.pumpAndSettle();

      final suggestions = find.byType(ListTile);
      expect(suggestions, findsWidgets);

      await tester.tap(suggestions.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final postalChooserTitle = find.textContaining('Choisir le code postal');
      if (postalChooserTitle.evaluate().isNotEmpty) {
        final postalOptions = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              RegExp(r'^\d{5}$').hasMatch(widget.data?.trim() ?? ''),
        );
        expect(postalOptions, findsWidgets);
        await tester.tap(postalOptions.first);
        await tester.pumpAndSettle();
      }

      expect(selectedEntry, isNotNull);
      expect(cityController.text.trim(), isNotEmpty);
      expect(postalCodeController.text, matches(RegExp(r'^\d{5}$')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sélection sans CP remplit uniquement la ville', (tester) async {
    await pumpField(tester);

    final entry = CityEntry(
      name: 'Ville sans CP',
      dept: '99',
      cps: const <String>[],
      nameNorm: 'villesanscp',
    );
    autocomplete(tester).onSelected?.call(entry);
    await tester.pumpAndSettle();

    expect(cityController.text, 'Ville sans CP');
    expect(postalCodeController.text, isEmpty);
    expect(selectedEntry, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sélection à un CP remplit ville CP et callback', (tester) async {
    await pumpField(tester);

    final entry = CityEntry(
      name: 'Ville un CP',
      dept: '99',
      cps: const <String>['12345'],
      nameNorm: 'villeuncp',
    );
    autocomplete(tester).onSelected?.call(entry);
    await tester.pumpAndSettle();

    expect(cityController.text, 'Ville un CP');
    expect(postalCodeController.text, '12345');
    expect(selectedEntry, same(entry));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sélection multi CP conserve le CP déjà saisi', (tester) async {
    // Prérempli avant initState : aucun debounce postal n'est programmé.
    postalCodeController.text = '12346';
    await pumpField(tester);

    final entry = CityEntry(
      name: 'Ville multi CP',
      dept: '99',
      cps: const <String>['12345', '12346'],
      nameNorm: 'villemulticp',
    );
    autocomplete(tester).onSelected?.call(entry);
    await tester.pumpAndSettle();

    expect(cityController.text, 'Ville multi CP');
    expect(postalCodeController.text, '12346');
    expect(selectedEntry, same(entry));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sélection multi CP ouvre le choix puis applique le CP choisi',
      (tester) async {
    await pumpField(tester);

    final entry = CityEntry(
      name: 'Ville choix CP',
      dept: '99',
      cps: const <String>['12345', '12346'],
      nameNorm: 'villechoixcp',
    );
    autocomplete(tester).onSelected?.call(entry);
    await tester.pumpAndSettle();

    expect(find.textContaining('Choisir le code postal'), findsOneWidget);
    expect(find.text('12345'), findsOneWidget);
    expect(find.text('12346'), findsOneWidget);

    await tester.tap(find.text('12346'));
    await tester.pumpAndSettle();

    expect(cityController.text, 'Ville choix CP');
    expect(postalCodeController.text, '12346');
    expect(selectedEntry, same(entry));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'une saisie manuelle courte et un CP incomplet restent sans appel distant',
    (tester) async {
      await pumpField(tester);

      final cityField = find.byType(TextFormField);
      await tester.tap(cityField);
      await tester.enterText(cityField, 'Xx');
      postalCodeController.text = '9719';

      await tester.pump(const Duration(milliseconds: 281));
      await tester.pumpAndSettle();

      expect(cityController.text, 'Xx');
      expect(postalCodeController.text, '9719');
      expect(selectedEntry, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dispose annule les debounces encore actifs', (tester) async {
    await pumpField(tester);

    final cityField = find.byType(TextFormField);
    await tester.tap(cityField);
    await tester.enterText(cityField, 'Ab');
    postalCodeController.text = '9719';

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });
}
