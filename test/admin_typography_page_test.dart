import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/app/typography_settings.dart';
import 'package:presto_app/pages/admin_typography_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1900);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    const MaterialApp(home: AdminTypographyPage()),
  );
  await tester.pump();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    450,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    typographySettings.reset();
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    typographySettings.reset();
    await Future<void>.delayed(Duration.zero);
  });

  testWidgets('renders all typography administration sections',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpPage(tester);

    expect(find.text('✍️  Gestion Typographie'), findsOneWidget);
    expect(find.text('État actuel'), findsOneWidget);
    expect(find.text("Portée: toute l'application"), findsOneWidget);
    expect(find.text('Taille du texte'), findsOneWidget);
    expect(find.text('Épaisseur (graisse)'), findsOneWidget);
    expect(find.text('Polices disponibles'), findsOneWidget);
    expect(find.text('Inter'), findsAtLeastNWidgets(1));
    expect(find.text('Rubik'), findsAtLeastNWidgets(1));
    expect(find.text('Nunito'), findsAtLeastNWidgets(1));

    await _scrollTo(tester, find.text('Aperçu en direct'));
    expect(find.text('Aperçu en direct'), findsOneWidget);
    expect(find.text('Titre de section'), findsOneWidget);
    expect(find.textContaining('Texte courant'), findsOneWidget);
    expect(find.text('Réinitialiser'), findsNothing);
  });

  testWidgets('changes scale and weight then applies and resets globally',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpPage(tester);

    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    expect(sliders, hasLength(2));
    sliders[0].onChanged!(1.2);
    await tester.pump();
    final updatedSliders =
        tester.widgetList<Slider>(find.byType(Slider)).toList();
    updatedSliders[1].onChanged!(2);
    await tester.pump();

    expect(find.text('Modifications en attente'), findsOneWidget);
    expect(find.text('+2 très gras'), findsAtLeastNWidgets(1));
    expect(find.text('Réinitialiser'), findsOneWidget);

    await _scrollTo(
      tester,
      find.text("Appliquer pour toute l'application"),
    );
    await tester.tap(find.text("Appliquer pour toute l'application"));
    await tester.pump();

    expect(typographySettings.scale, 1.2);
    expect(typographySettings.fontWeightDelta, 2);
    expect(find.text('✅ Typographie appliquée'), findsOneWidget);
    expect(find.text('Modifications en attente'), findsNothing);

    await tester.tap(find.text('Réinitialiser'));
    await tester.pump();
    expect(typographySettings.scale, 1);
    expect(typographySettings.fontFamily, 'Inter');
    expect(typographySettings.fontWeightDelta, 0);
    expect(find.text('🔄 Réinitialisation appliquée'), findsOneWidget);
  });

  testWidgets('searches, clears and selects an available font',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpPage(tester);

    final search = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == '🔍 Rechercher une police...',
    );
    expect(search, findsOneWidget);

    await tester.enterText(search, 'rub');
    await tester.pump();
    expect(find.text('Rubik'), findsOneWidget);
    expect(find.text('Nunito'), findsNothing);

    await tester.tap(find.byIcon(Icons.clear_rounded));
    await tester.pump();
    expect(find.text('Nunito'), findsOneWidget);

    await tester.enterText(search, 'police inconnue');
    await tester.pump();
    expect(find.text('Aucune police trouvée'), findsOneWidget);

    await tester.enterText(search, 'Rubik');
    await tester.pump();
    await tester.tap(find.text('Rubik'));
    await tester.pump();
    expect(find.text('✅ Police "Rubik" sélectionnée'), findsOneWidget);
    expect(find.text('Modifications en attente'), findsOneWidget);
  });

  testWidgets('validates, adds and deletes a custom font', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpPage(tester);

    await tester.tap(find.byTooltip('Ajouter une nouvelle police'));
    await tester.pump();
    expect(find.text('➕ Ajouter une nouvelle police'), findsOneWidget);

    final addField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText ==
              'Ex: Roboto, Poppins, Playfair...',
    );
    expect(addField, findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter'));
    await tester.pump();
    expect(find.text('❌ Nom requis'), findsOneWidget);

    await tester.enterText(addField, 'Inter');
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter'));
    await tester.pump();
    expect(find.text('❌ Police déjà présente'), findsOneWidget);

    await tester.enterText(addField, 'Bad Font!');
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter'));
    await tester.pump();
    expect(
      find.text('❌ Caractères valides : lettres, chiffres, tirets'),
      findsOneWidget,
    );

    await tester.enterText(addField, 'Custom_Font');
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter'));
    await tester.pump();
    expect(find.text('✅ Police "Custom_Font" ajoutée'), findsOneWidget);
    expect(find.text('Custom_Font'), findsOneWidget);

    await tester.longPress(find.text('Custom_Font'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer la police ?'), findsOneWidget);
    expect(find.textContaining('Custom_Font'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Custom_Font'), findsOneWidget);

    await tester.longPress(find.text('Custom_Font'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('✅ Police supprimée'), findsOneWidget);
    expect(find.text('Custom_Font'), findsNothing);
  });

  testWidgets('closes the add-font panel without changing the list',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpPage(tester);

    await tester.tap(find.byTooltip('Ajouter une nouvelle police'));
    await tester.pump();
    final addField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText ==
              'Ex: Roboto, Poppins, Playfair...',
    );
    await tester.enterText(addField, 'Temporary');
    await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
    await tester.pump();

    expect(find.text('➕ Ajouter une nouvelle police'), findsNothing);
    expect(find.text('Temporary'), findsNothing);
  });
}
