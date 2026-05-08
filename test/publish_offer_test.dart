import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/main.dart' as app;
import 'package:presto_app/widgets/photo_selector_tile.dart';

void main() {
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
  });
}
