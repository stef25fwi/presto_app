import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/main.dart' as app;
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
    final textMode = find.text('Texte + IA');
    expect(textMode, findsOneWidget);
    await tester.ensureVisible(textMode);
    await tester.tap(textMode);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<List<String>> openDropdown(
    WidgetTester tester,
    Finder dropdown,
  ) async {
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(DropdownMenuItem<String>),
            matching: find.byType(Text),
          ),
        )
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList(growable: false);

    expect(labels, isNotEmpty);
    return labels;
  }

  Future<String> selectDropdownValue(
    WidgetTester tester,
    Finder dropdown, {
    int index = 0,
  }) async {
    final labels = await openDropdown(tester, dropdown);
    final safeIndex = index.clamp(0, labels.length - 1);
    final selected = labels[safeIndex];
    await tester.tap(find.text(selected).last);
    await tester.pumpAndSettle();
    return selected;
  }

  testWidgets('bascule entre IA vocale et texte sans perdre le brouillon',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('Appuyez pour parler'), findsOneWidget);
    expect(find.text("Parlez, l'IA complète l'annonce"), findsOneWidget);

    await selectTextMode(tester);
    expect(find.text('Appuyez pour parler'), findsNothing);
    expect(find.text("Photos de l'offre"), findsOneWidget);

    const description =
        'Je recherche une personne soigneuse pour repeindre une chambre.';
    const title = 'Peinture chambre';
    final fields = find.byType(TextFormField);
    expect(fields, findsAtLeastNWidgets(2));
    await tester.enterText(fields.first, description);
    await tester.enterText(fields.at(1), title);
    await tester.pump();

    await tester.tap(find.text('IA vocale'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Appuyez pour parler'), findsOneWidget);

    await selectTextMode(tester);
    expect(find.text(description), findsOneWidget);
    expect(find.text(title), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ouvre et ferme le choix de source photo sans lancer le plugin',
      (tester) async {
    await pumpPage(tester);
    await selectTextMode(tester);

    final photoTile = find.byType(PhotoSelectorTile);
    expect(photoTile, findsOneWidget);
    await tester.ensureVisible(photoTile);
    await tester.tap(photoTile);
    await tester.pumpAndSettle();

    expect(find.text('Galerie'), findsOneWidget);
    expect(find.text('Appareil photo'), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Galerie'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sélectionne catégorie puis sous-catégorie et change de catégorie',
      (tester) async {
    await pumpPage(tester);
    await selectTextMode(tester);

    var dropdowns = find.byType(DropdownButtonFormField<String>);
    expect(dropdowns, findsAtLeastNWidgets(3));

    final firstCategory =
        await selectDropdownValue(tester, dropdowns.first, index: 0);
    expect(firstCategory, isNotEmpty);
    expect(find.text('Sous-catégorie'), findsOneWidget);

    dropdowns = find.byType(DropdownButtonFormField<String>);
    final selectedSubcategory =
        await selectDropdownValue(tester, dropdowns.at(1), index: 0);
    expect(selectedSubcategory, isNotEmpty);

    dropdowns = find.byType(DropdownButtonFormField<String>);
    final categories = await openDropdown(tester, dropdowns.first);
    final nextIndex = categories.length > 1 ? 1 : 0;
    final nextCategory = categories[nextIndex];
    await tester.tap(find.text(nextCategory).last);
    await tester.pumpAndSettle();

    expect(find.text(nextCategory), findsWidgets);
    expect(find.text('Sous-catégorie'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('transmet réellement la progression de défilement au parent',
      (tester) async {
    final offsets = <double>[];
    await pumpPage(
      tester,
      size: const Size(430, 850),
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
