import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/widgets/home_interactions.dart';

void main() {
  testWidgets('affiche le message par défaut pour une catégorie', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: HomeCategoryChip(
              icon: Icons.build,
              label: 'Bricolage',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Bricolage'));
    await tester.pump();

    expect(
      find.text('Catégorie "Bricolage" : bientôt disponible'),
      findsOneWidget,
    );
  });
}
