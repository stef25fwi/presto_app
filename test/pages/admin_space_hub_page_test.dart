import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin_space_hub_page.dart';

void main() {
  testWidgets('affiche les domaines admin sous forme de tuiles cliquables',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdminSpaceHubPage()),
    );

    expect(find.text('Configuration & conformité'), findsOneWidget);
    expect(find.text('Acquisition & trafic'), findsOneWidget);
    expect(find.text('Annonces & contenu'), findsOneWidget);
    expect(find.text('Utilisateurs'), findsOneWidget);
    expect(find.text('Engagement'), findsOneWidget);
    expect(find.text('Transactions & revenus'), findsOneWidget);
    expect(find.text('Qualité & modération'), findsOneWidget);
    expect(find.text('Technique & performance'), findsOneWidget);

    await tester.tap(find.text('Acquisition & trafic'));
    await tester.pumpAndSettle();

    expect(find.text('Indicateurs suivis'), findsOneWidget);
    expect(find.text('Ouvrir le dashboard détaillé'), findsOneWidget);
  });

  testWidgets('reste sans débordement sur smartphone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: AdminSpaceHubPage()),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Acquisition & trafic'), findsOneWidget);
  });
}
