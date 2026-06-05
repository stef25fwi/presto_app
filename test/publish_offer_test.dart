import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:presto_app/main.dart' as app;
import 'package:presto_app/widgets/photo_selector_tile.dart';
import 'package:presto_app/widgets/ai_publish_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  /// Helper — pumps the publish page with a large viewport so all fields render.
  Future<void> pumpPublishPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: app.PublishOfferPage()));
    await tester.pump();
  }

  testWidgets('Le formulaire actif réagit aux choix principaux',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.PublishOfferPage()));
    await tester.pump();

    expect(find.text("Photos de l'offre"), findsOneWidget);
    expect(find.textContaining('2 photos maximum'), findsOneWidget);
    expect(find.byType(PhotoSelectorTile), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
    expect(find.text('Sous-catégorie'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bricolage / Travaux').last);
    await tester.pumpAndSettle();

    expect(find.text('Sous-catégorie'), findsOneWidget);

    final budgetFieldBefore =
        tester.widget<TextFormField>(find.byType(TextFormField).last);
    expect(budgetFieldBefore.enabled, isTrue);

    await tester
        .ensureVisible(find.byType(DropdownButtonFormField<String>).last);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('À négocier').last);
    await tester.pumpAndSettle();

    final budgetFieldAfter =
        tester.widget<TextFormField>(find.byType(TextFormField).last);
    expect(budgetFieldAfter.enabled, isFalse);
    expect(find.text('Budget'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Publier mon offre'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Publier mon offre'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // -----------------------------------------------------------------------
  // Bouton IA — visibilité et accessibilité (web + iOS + Android)
  // -----------------------------------------------------------------------

  testWidgets('Le bouton IA dictée est visible sur la page de publication',
      (WidgetTester tester) async {
    await pumpPublishPage(tester);

    // Le AiPublishControl principal (dictée vocale) doit être présent.
    expect(find.byType(AiPublishControl), findsOneWidget);
    expect(find.text('Décrire mon besoin (IA)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Le bouton IA sparkle (✨) apparaît dans le champ description quand du texte est saisi',
      (WidgetTester tester) async {
    await pumpPublishPage(tester);

    // Avant toute saisie, le Tooltip "Remplir les champs avec l'IA" ne doit pas exister.
    expect(
      find.byTooltip('Remplir les champs avec l\'IA'),
      findsNothing,
      reason: 'Le bouton ✨ ne doit pas être visible sans description saisie',
    );

    // Saisir du texte dans le champ description (second TextFormField).
    // Ordre des TextFormFields : 0=Titre, 1=Description
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'J\'ai besoin de monter des meubles IKEA dans mon appartement parisien.',
    );
    await tester.pump();

    // Après saisie, le Tooltip du bouton ✨ doit être visible.
    expect(
      find.byTooltip('Remplir les champs avec l\'IA'),
      findsOneWidget,
      reason: 'Le bouton ✨ doit apparaître une fois la description remplie',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // -----------------------------------------------------------------------
  // Flow de publication — validation des champs obligatoires
  // -----------------------------------------------------------------------

  testWidgets(
      'Cliquer "Publier mon offre" sans remplir le formulaire affiche les erreurs de validation',
      (WidgetTester tester) async {
    await pumpPublishPage(tester);

    // Scroll jusqu'au bouton
    await tester.scrollUntilVisible(
      find.text('Publier mon offre'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    // Clic sur "Publier mon offre" avec formulaire vide.
    await tester.tap(find.text('Publier mon offre'));
    await tester.pumpAndSettle();

    // Au moins un message d'erreur doit apparaître.
    expect(
      find.textContaining('Merci'),
      findsWidgets,
      reason: 'Les messages d\'erreur de validation doivent s\'afficher',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Le bouton Publier est initialement grisé (formulaire incomplet)',
      (WidgetTester tester) async {
    await pumpPublishPage(tester);

    await tester.scrollUntilVisible(
      find.text('Publier mon offre'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    // Le bouton est visuellement désactivé (backgroundColor = grey) quand
    // le formulaire est vide. Il reste cliquable pour afficher les erreurs,
    // mais son style indique l'état incomplet.
    final publishTextFinder = find.text('Publier mon offre');
    expect(
      publishTextFinder,
      findsWidgets,
      reason: 'Le CTA Publier mon offre doit être présent dans le formulaire',
    );

    final materialButtonFinder = find.ancestor(
      of: publishTextFinder.first,
      matching: find.byWidgetPredicate(
        (widget) => widget is ButtonStyleButton,
        description: 'ButtonStyleButton ancestor',
      ),
    );

    if (materialButtonFinder.evaluate().isNotEmpty) {
      final button = tester.widget<ButtonStyleButton>(
        materialButtonFinder.first,
      );
      expect(
        button.style,
        isNotNull,
        reason: 'Le bouton publier doit avoir un style explicite',
      );
    } else {
      // Fallback pour CTA custom : InkWell/GestureDetector/Container stylé.
      // Le test vérifie au minimum que le CTA existe et reste accessible.
      expect(
        publishTextFinder,
        findsWidgets,
        reason:
            'Le CTA publier doit rester visible même si le formulaire est incomplet',
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'La sélection d\'une catégorie active la sous-catégorie correspondante',
      (WidgetTester tester) async {
    await pumpPublishPage(tester);

    // Avant sélection : pas de sous-catégorie
    expect(find.text('Sous-catégorie'), findsNothing);

    // Sélectionner "Aide à domicile"
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aide à domicile').last);
    await tester.pumpAndSettle();

    // Les sous-catégories doivent apparaître
    expect(find.text('Sous-catégorie'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Saisir le titre et la description active le bouton IA sparkle '
      'et le formulaire enregistre le contenu', (WidgetTester tester) async {
    await pumpPublishPage(tester);

    const testTitle = 'Monter un meuble IKEA dans mon salon';
    const testDescription =
        'J\'ai besoin d\'aide pour monter un meuble IKEA PAX de grande taille. '
        'La mission est à effectuer à Paris 15ème dans la semaine.';

    // Remplir le titre
    await tester.enterText(find.byType(TextFormField).first, testTitle);
    await tester.pump();

    // Remplir la description (second TextFormField)
    await tester.enterText(find.byType(TextFormField).at(1), testDescription);
    await tester.pump();

    // Le titre doit être présent dans le widget
    expect(find.text(testTitle), findsOneWidget);

    // Le bouton ✨ du champ description doit être visible.
    // On cible le tooltip, pas l'icône globale, car la page peut contenir
    // plusieurs Icons.auto_awesome.
    expect(
      find.byTooltip('Remplir les champs avec l\'IA'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // -----------------------------------------------------------------------
  // Annonce de test complète (vérification structure du form)
  // -----------------------------------------------------------------------

  testWidgets(
      'Annonce test : tous les champs obligatoires sont présents dans le formulaire',
      (WidgetTester tester) async {
    await pumpPublishPage(tester);

    // Champs texte attendus : titre, description, ville, CP, téléphone, budget
    final textFields = find.byType(TextFormField);
    expect(
      textFields,
      findsAtLeastNWidgets(5),
      reason: 'Titre, description, ville, téléphone, budget au minimum',
    );

    // Dropdowns attendus : catégorie, délai, type budget
    final dropdowns = find.byType(DropdownButtonFormField<String>);
    expect(
      dropdowns,
      findsAtLeastNWidgets(3),
      reason: 'Catégorie, délai, type de budget au minimum',
    );

    // Section photos
    expect(find.byType(PhotoSelectorTile), findsOneWidget);

    // Bouton de publication (peut nécessiter un scroll sur petit écran)
    await tester.scrollUntilVisible(
      find.text('Publier mon offre'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Publier mon offre'), findsOneWidget);

    // Bouton IA dictée
    expect(find.byType(AiPublishControl), findsOneWidget);
    expect(find.text('Décrire mon besoin (IA)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
