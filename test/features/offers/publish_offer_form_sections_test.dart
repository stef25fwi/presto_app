import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_category_fields.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_contact_fields.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_mission_fields.dart';
import 'package:presto_app/widgets/city_postal_autocomplete_field.dart';

void main() {
  testWidgets('catégorie requise et sous-catégorie conditionnelle',
      (tester) async {
    final formKey = GlobalKey<FormState>();
    String? category;
    String? subcategory;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: PublishOfferCategoryFields(
              categoryLabel: const Text('Catégorie'),
              categories: const ['Maison', 'Jardin'],
              subcategories: const [],
              selectedCategory: null,
              selectedSubcategory: null,
              onCategoryChanged: (value) => category = value,
              onSubcategoryChanged: (value) => subcategory = value,
            ),
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Merci de choisir une catégorie'), findsOneWidget);
    expect(find.text('Sous-catégorie'), findsNothing);

    final categoryField = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).first,
    );
    categoryField.onChanged?.call('Maison');
    expect(category, 'Maison');
    expect(subcategory, isNull);
  });

  testWidgets('affiche la sous-catégorie quand une catégorie est choisie',
      (tester) async {
    String? selectedSubcategory;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublishOfferCategoryFields(
            categoryLabel: const Text('Catégorie'),
            categories: const ['Maison'],
            subcategories: const ['Montage de meuble'],
            selectedCategory: 'Maison',
            selectedSubcategory: null,
            onCategoryChanged: (_) {},
            onSubcategoryChanged: (value) => selectedSubcategory = value,
          ),
        ),
      ),
    );

    expect(find.text('Sous-catégorie'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));

    final subcategoryField = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).last,
    );
    subcategoryField.onChanged?.call('Montage de meuble');
    expect(selectedSubcategory, 'Montage de meuble');
  });

  testWidgets('localisation conserve les contrôleurs et décorateurs',
      (tester) async {
    final cityController = TextEditingController();
    final postalController = TextEditingController();
    addTearDown(cityController.dispose);
    addTearDown(postalController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublishOfferLocationFields(
            cityController: cityController,
            postalCodeController: postalController,
            cityLabel: const Text('Ville'),
            onCitySelected: (_) {},
            onPostalTap: () {},
            onPostalEditingComplete: () {},
            postalValidator: (_) => null,
            cityDecorator: (child) => KeyedSubtree(
              key: const Key('city-decoration'),
              child: child,
            ),
            postalDecorator: (child) => KeyedSubtree(
              key: const Key('postal-decoration'),
              child: child,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Localisation'), findsOneWidget);
    expect(find.byType(CityPostalAutocompleteField), findsOneWidget);
    expect(find.byKey(const Key('city-decoration')), findsOneWidget);
    expect(find.byKey(const Key('postal-decoration')), findsOneWidget);
  });

  testWidgets('option téléphone masqué transmet la nouvelle valeur',
      (tester) async {
    final phoneController = TextEditingController();
    addTearDown(phoneController.dispose);
    bool? nextVisibility;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublishOfferPhoneFields(
            controller: phoneController,
            label: const Text('Téléphone'),
            hintText: '690123456',
            initialCountryCode: '+590',
            onCountryCodeChanged: (_) {},
            onPhoneChanged: (_) {},
            validator: (_) => null,
            hidePhone: false,
            onHidePhoneChanged: (value) => nextVisibility = value,
          ),
        ),
      ),
    );

    await tester.tap(find.textContaining('Masquer mon numéro'));
    await tester.pump();
    expect(nextVisibility, isTrue);
  });

  testWidgets('délai et type de budget transmettent les changements',
      (tester) async {
    final budgetController = TextEditingController(text: '120');
    addTearDown(budgetController.dispose);
    String? delay;
    String? budgetType;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublishOfferMissionFields(
            delayLabel: const Text('Délai'),
            delayOptions: const ['Urgent', 'Cette semaine'],
            selectedDelay: null,
            onDelayChanged: (value) => delay = value,
            budgetTypes: const ['Fixe', 'À négocier'],
            selectedBudgetType: 'Fixe',
            budgetController: budgetController,
            budgetLabel: const Text('Budget (€)'),
            onBudgetTypeChanged: (value) => budgetType = value,
            budgetValidator: (_) => null,
          ),
        ),
      ),
    );

    final dropdowns = find.byType(DropdownButtonFormField<String>);
    expect(dropdowns, findsNWidgets(2));

    tester
        .widget<DropdownButtonFormField<String>>(dropdowns.first)
        .onChanged
        ?.call('Urgent');
    tester
        .widget<DropdownButtonFormField<String>>(dropdowns.last)
        .onChanged
        ?.call('À négocier');

    expect(delay, 'Urgent');
    expect(budgetType, 'À négocier');
  });
}
