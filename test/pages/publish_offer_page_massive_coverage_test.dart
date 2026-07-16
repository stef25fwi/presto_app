import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/offers/presentation/widgets/publish_offer_category_fields.dart';
import 'package:presto_app/main.dart' as app;
import 'package:presto_app/widgets/ai_publish_control.dart';
import 'package:presto_app/widgets/photo_selector_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    ValueChanged<double>? onScroll,
    Size size = const Size(900, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: app.PublishOfferPage(onScroll: onScroll),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> selectTextMode(WidgetTester tester) async {
    final control = tester.widget<AiPublishControl>(find.byType(AiPublishControl));
    control.onSelectText();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> selectVocalMode(WidgetTester tester) async {
    final control = tester.widget<AiPublishControl>(find.byType(AiPublishControl));
    control.onSelectVocal();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('bascule entre IA vocale et texte sans perdre le brouillon',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('Appuyez pour parler'), findsOneWidget);
    expect(find.text("Parlez, l'IA complète l'annonce pour vous."), findsOneWidget);

    await selectTextMode(tester);
    expect(find.text("Photos de l'offre"), findsOneWidget);

    const description =
        'Je recherche une personne soigneuse pour repeindre une chambre.';
    const title = 'Peinture chambre';
    final fields = find.byType(TextFormField);
    expect(fields, findsAtLeastNWidgets(2));
    await tester.enterText(fields.first, description);
    await tester.enterText(fields.at(1), title);
    await tester.pump();

    await selectVocalMode(tester);
    expect(find.text('Appuyez pour parler'), findsOneWidget);

    await selectTextMode(tester);
    final values = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .map((field) => field.controller.text)
        .toList(growable: false);
    expect(values, contains(description));
    expect(values, contains(title));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ouvre et ferme le choix de source photo sans lancer le plugin',
      (tester) async {
    await pumpPage(tester);
    await selectTextMode(tester);

    final photoTile = find.byType(PhotoSelectorTile);
    expect(photoTile, findsOneWidget);
    tester.widget<PhotoSelectorTile>(photoTile).onTap();
    await tester.pumpAndSettle();

    expect(find.text('Galerie'), findsOneWidget);
    expect(find.text('Appareil photo'), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);

    Navigator.of(tester.element(find.text('Galerie'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Galerie'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sélectionne catégorie puis sous-catégorie et change de catégorie',
      (tester) async {
    await pumpPage(tester);
    await selectTextMode(tester);

    var categoryFields = tester.widget<PublishOfferCategoryFields>(
      find.byType(PublishOfferCategoryFields),
    );
    expect(categoryFields.categories, isNotEmpty);

    final firstCategory = categoryFields.categories.first;
    categoryFields.onCategoryChanged(firstCategory);
    await tester.pumpAndSettle();

    categoryFields = tester.widget<PublishOfferCategoryFields>(
      find.byType(PublishOfferCategoryFields),
    );
    expect(categoryFields.selectedCategory, firstCategory);
    expect(categoryFields.subcategories, isNotEmpty);
    expect(find.text('Sous-catégorie'), findsOneWidget);

    final firstSubcategory = categoryFields.subcategories.first;
    categoryFields.onSubcategoryChanged(firstSubcategory);
    await tester.pumpAndSettle();

    categoryFields = tester.widget<PublishOfferCategoryFields>(
      find.byType(PublishOfferCategoryFields),
    );
    expect(categoryFields.selectedSubcategory, firstSubcategory);

    final nextCategory = categoryFields.categories.length > 1
        ? categoryFields.categories[1]
        : firstCategory;
    categoryFields.onCategoryChanged(nextCategory);
    await tester.pumpAndSettle();

    categoryFields = tester.widget<PublishOfferCategoryFields>(
      find.byType(PublishOfferCategoryFields),
    );
    expect(categoryFields.selectedCategory, nextCategory);
    expect(categoryFields.selectedSubcategory, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('transmet réellement la progression de défilement au parent',
      (tester) async {
    final offsets = <double>[];
    await pumpPage(
      tester,
      size: const Size(900, 900),
      onScroll: offsets.add,
    );
    await selectTextMode(tester);
    offsets.clear();

    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -700));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(offsets, isNotEmpty);
    expect(offsets.any((offset) => offset > 0), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
