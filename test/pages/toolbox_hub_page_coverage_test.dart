import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/toolbox_hub_page.dart';

void main() {
  Future<void> pumpHub(
    WidgetTester tester, {
    required Size size,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: ToolboxHubPage()),
    );
    await tester.pump();
  }

  testWidgets('renders both toolbox cards on a phone', (tester) async {
    await pumpHub(tester, size: const Size(390, 844));

    expect(find.text('Boîte à outils'), findsOneWidget);
    expect(find.text('Je me lance !'), findsOneWidget);
    expect(find.text("La calculatrice de l'entrepreneur"), findsOneWidget);
    expect(find.text('Démarrer mon projet'), findsOneWidget);
    expect(find.text('Calculer mon prix'), findsOneWidget);
    expect(find.text('Statut juridique conseillé'), findsOneWidget);
    expect(find.text('Positionnement face à la concurrence'), findsOneWidget);
    expect(find.byIcon(Icons.rocket_launch_rounded), findsOneWidget);
    expect(find.byIcon(Icons.calculate_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(8));

    final buttons = tester.widgetList<ElevatedButton>(find.byType(ElevatedButton));
    expect(buttons.length, 2);
    for (final button in buttons) {
      expect(button.onPressed, isNotNull);
    }
  });

  testWidgets('renders desktop layout and keeps actions available', (tester) async {
    await pumpHub(tester, size: const Size(1280, 900));

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNWidgets(2));
    expect(find.text('Décris ton projet, ta situation et ton territoire.'), findsOneWidget);
    expect(
      find.text(
        'En quelques clics, calcule ton coût de revient, ton prix de vente conseillé et compare avec le marché.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses compact button height on a short screen', (tester) async {
    await pumpHub(tester, size: const Size(350, 620));

    final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
    expect(
      sizedBoxes.where((box) => box.height == 52 && box.width == double.infinity),
      hasLength(2),
    );
  });
}
