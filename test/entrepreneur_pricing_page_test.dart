import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/entrepreneur_pricing_page.dart';

void main() {
  testWidgets('header back returns to root page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const EntrepreneurPricingPage(),
                ),
              ),
              child: const Text('Open calculator'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open calculator'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pricing-header-back')));
    await tester.pumpAndSettle();

    expect(find.text('Open calculator'), findsOneWidget);
  });

  testWidgets('expert mode exposes machines and accessories', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: EntrepreneurPricingPage()),
    );

    await tester.tap(find.text('Mode Expert').first);
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('6. Machines et accessoires utilisés').first,
      500,
    );

    expect(find.text('Ajouter une machine'), findsOneWidget);
    expect(find.text('Ajouter un accessoire'), findsOneWidget);
    expect(find.text('Tarif électricité'), findsOneWidget);
  });
}