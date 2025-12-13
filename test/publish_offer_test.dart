import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/publish_offer_page.dart';

void main() {
  testWidgets('Publication d\'une offre - bouton en bas et validation formulaire', (WidgetTester tester) async {
    // Affiche la page
    await tester.pumpWidget(const MaterialApp(home: PublishOfferPage()));

    // Vérifie la présence du bouton
    final publishButton = find.widgetWithText(ElevatedButton, "Publier l'offre");
    expect(publishButton, findsOneWidget);

    // Remplit les champs obligatoires
    await tester.enterText(find.byType(TextFormField).at(0), 'Titre test');
    await tester.enterText(find.byType(TextFormField).at(1), 'Description test');
    await tester.enterText(find.byType(TextFormField).at(2), 'Paris');
    await tester.enterText(find.byType(TextFormField).at(3), '75001');

    // Appuie sur le bouton
    await tester.tap(publishButton);
    await tester.pumpAndSettle();

    // Vérifie qu'un SnackBar de succès ou d'erreur s'affiche
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
