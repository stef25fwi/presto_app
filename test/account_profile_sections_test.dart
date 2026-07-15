import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/account_profile_sections.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

Finder _textFieldWithLabel(String label) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == label,
  );
}

class _Controllers {
  final department = TextEditingController(text: '971');
  final pseudo = TextEditingController();
  final city = TextEditingController();
  final phone = TextEditingController();

  void dispose() {
    department.dispose();
    pseudo.dispose();
    city.dispose();
    phone.dispose();
  }
}

AccountProfileFormSection _profile({
  Key? key,
  required _Controllers controllers,
  required bool isEditing,
  required bool isSaving,
  String firstName = '',
  String lastName = '',
  String phoneCountryCode = '+33',
  bool showTitle = true,
  required VoidCallback onStartEditing,
  required Future<void> Function() onSave,
  required ValueChanged<String> onPhoneCountryCodeChanged,
}) {
  return AccountProfileFormSection(
    key: key,
    firstName: firstName,
    lastName: lastName,
    departmentController: controllers.department,
    pseudoController: controllers.pseudo,
    cityController: controllers.city,
    phoneController: controllers.phone,
    phoneCountryCode: phoneCountryCode,
    isEditing: isEditing,
    isSaving: isSaving,
    showTitle: showTitle,
    onStartEditing: onStartEditing,
    onSave: onSave,
    onPhoneCountryCodeChanged: onPhoneCountryCodeChanged,
  );
}

void main() {
  testWidgets('renders the read-only profile and starts editing',
      (tester) async {
    final controllers = _Controllers();
    addTearDown(controllers.dispose);
    var editCount = 0;

    await tester.pumpWidget(
      _host(
        _profile(
          controllers: controllers,
          isEditing: false,
          isSaving: false,
          onStartEditing: () => editCount++,
          onSave: () async {},
          onPhoneCountryCodeChanged: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Non renseigné'), findsNWidgets(2));
    expect(find.text('Modifier mon profil'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    final absorbers = tester.widgetList<AbsorbPointer>(find.byType(AbsorbPointer));
    expect(
      absorbers.where((widget) => widget.absorbing).length,
      greaterThanOrEqualTo(2),
    );

    await tester.tap(find.text('Modifier mon profil'));
    expect(editCount, 1);
  });

  testWidgets('renders the editable profile and saves it', (tester) async {
    final controllers = _Controllers();
    addTearDown(controllers.dispose);
    controllers.pseudo.text = 'Stef971';
    controllers.city.text = 'Baie-Mahault (97122)';
    var saveCount = 0;

    await tester.pumpWidget(
      _host(
        _profile(
          controllers: controllers,
          firstName: '  Stef  ',
          lastName: '  Stefan  ',
          isEditing: true,
          isSaving: false,
          showTitle: false,
          onStartEditing: () {},
          onSave: () async => saveCount++,
          onPhoneCountryCodeChanged: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Mon profil'), findsNothing);
    expect(find.text('Stef'), findsOneWidget);
    expect(find.text('Stefan'), findsOneWidget);
    expect(find.text('Enregistrer mon profil'), findsOneWidget);
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);

    await tester.tap(find.text('Enregistrer mon profil'));
    await tester.pump();
    expect(saveCount, 1);
  });

  testWidgets('disables profile saving while a save is in progress',
      (tester) async {
    final controllers = _Controllers();
    addTearDown(controllers.dispose);
    var saveCount = 0;

    await tester.pumpWidget(
      _host(
        _profile(
          controllers: controllers,
          isEditing: true,
          isSaving: true,
          onStartEditing: () {},
          onSave: () async => saveCount++,
          onPhoneCountryCodeChanged: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Enregistrement...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    expect(saveCount, 0);
  });

  testWidgets('derives every supported phone country code from postal codes',
      (tester) async {
    final cases = <({String city, String initialCode, String expected})>[
      (city: 'Pointe-à-Pitre (97110)', initialCode: '+33', expected: '+590'),
      (city: 'Fort-de-France (97200)', initialCode: '+33', expected: '+596'),
      (city: 'Cayenne (97300)', initialCode: '+33', expected: '+594'),
      (city: 'Saint-Denis (97400)', initialCode: '+33', expected: '+262'),
      (city: 'Mamoudzou (97600)', initialCode: '+33', expected: '+262'),
      (city: 'Papeete (98714)', initialCode: '+33', expected: '+689'),
      (city: 'Paris (75001)', initialCode: '+590', expected: '+33'),
    ];

    for (final entry in cases) {
      final controllers = _Controllers();
      final codes = <String>[];
      await tester.pumpWidget(
        _host(
          _profile(
            key: UniqueKey(),
            controllers: controllers,
            isEditing: true,
            isSaving: false,
            phoneCountryCode: entry.initialCode,
            onStartEditing: () {},
            onSave: () async {},
            onPhoneCountryCodeChanged: codes.add,
          ),
        ),
      );
      await tester.pump();

      final cityField = _textFieldWithLabel('Ville');
      expect(cityField, findsOneWidget);
      await tester.enterText(cityField, entry.city);
      await tester.pump();

      expect(codes.last, entry.expected, reason: entry.city);
      expect(controllers.city.text, entry.city);
      controllers.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('keeps the current country code when the city maps to it',
      (tester) async {
    final controllers = _Controllers();
    addTearDown(controllers.dispose);
    final codes = <String>[];

    await tester.pumpWidget(
      _host(
        _profile(
          controllers: controllers,
          isEditing: true,
          isSaving: false,
          phoneCountryCode: '+590',
          onStartEditing: () {},
          onSave: () async {},
          onPhoneCountryCodeChanged: codes.add,
        ),
      ),
    );
    await tester.pump();
    final initialCalls = codes.length;

    await tester.enterText(
      _textFieldWithLabel('Ville'),
      'Les Abymes (97139)',
    );
    await tester.pump();

    expect(codes.length, initialCalls);
  });

  testWidgets('renders configured alert chips and forwards every action',
      (tester) async {
    final removedCategories = <String>[];
    final removedSubcategories = <String>[];
    final removedDepartments = <String>[];
    var categoryOpens = 0;
    var subcategoryOpens = 0;
    var departmentOpens = 0;
    var applyCount = 0;

    await tester.pumpWidget(
      _host(
        AccountFavoriteCategoriesSection(
          categoriesCount: 1,
          subcategoriesCount: 1,
          selectedCategories: const ['Ménage'],
          selectedSubcategories: const ['Nettoyage'],
          selectedDepartements: const ['971'],
          departementsCount: 1,
          isSaving: false,
          onOpenCategoryPicker: () => categoryOpens++,
          onOpenSubcategoryPicker: () => subcategoryOpens++,
          onOpenDeptPicker: () => departmentOpens++,
          onApply: () => applyCount++,
          onRemoveCategory: removedCategories.add,
          onRemoveSubcategory: removedSubcategories.add,
          onRemoveDepartement: removedDepartments.add,
        ),
      ),
    );

    expect(find.text('Mes alertes "Nouvelle annonce"'), findsOneWidget);
    expect(find.text('Alertes paramétrées'), findsOneWidget);
    expect(find.text('Ménage'), findsOneWidget);
    expect(find.text('Nettoyage'), findsOneWidget);
    expect(find.byType(Chip), findsNWidgets(3));

    final chips = tester.widgetList<Chip>(find.byType(Chip)).toList();
    chips[0].onDeleted!();
    chips[1].onDeleted!();
    chips[2].onDeleted!();
    expect(removedCategories, ['Ménage']);
    expect(removedDepartments, ['971']);
    expect(removedSubcategories, ['Nettoyage']);

    await tester.tap(find.text('1 département(s) sélectionné(s)'));
    await tester.tap(find.text('1 catégorie(s) sélectionnée(s)'));
    await tester.tap(find.text('1 sous-catégorie(s) sélectionnée(s)'));
    await tester.tap(find.text('Valider mes alertes'));

    expect(departmentOpens, 1);
    expect(categoryOpens, 1);
    expect(subcategoryOpens, 1);
    expect(applyCount, 1);
  });

  testWidgets('renders empty and saving alert states without a title',
      (tester) async {
    await tester.pumpWidget(
      _host(
        AccountFavoriteCategoriesSection(
          categoriesCount: 0,
          subcategoriesCount: 0,
          selectedCategories: const [],
          selectedSubcategories: const [],
          selectedDepartements: const [],
          departementsCount: 0,
          isSaving: true,
          showTitle: false,
          onOpenCategoryPicker: () {},
          onOpenSubcategoryPicker: () {},
          onOpenDeptPicker: () {},
          onApply: () {},
        ),
      ),
    );

    expect(find.text('Mes alertes "Nouvelle annonce"'), findsNothing);
    expect(find.text('Alertes paramétrées'), findsNothing);
    expect(find.text('Tous les départements'), findsOneWidget);
    expect(find.text('Choisir des catégories'), findsOneWidget);
    expect(find.text('Choisir des sous-catégories'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('opens messages and the professional profile', (tester) async {
    var messagesCount = 0;
    var proCount = 0;

    await tester.pumpWidget(
      _host(
        Column(
          children: [
            AccountMessagesSection(
              onOpenMessages: () => messagesCount++,
              showTitle: false,
            ),
            const SizedBox(height: 20),
            AccountProUpgradeSection(
              onOpenProProfile: () => proCount++,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Mes messages'), findsNothing);
    expect(find.text('Ouvrir mes messages'), findsOneWidget);
    expect(find.text('Vous êtes une entreprise ?'), findsOneWidget);
    expect(find.text('Créer mon profil Pro'), findsOneWidget);

    await tester.tap(find.text('Ouvrir mes messages'));
    await tester.tap(find.text('Créer mon profil Pro'));
    expect(messagesCount, 1);
    expect(proCount, 1);
  });
}
