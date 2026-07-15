import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_action_placeholders.dart';

void main() {
  Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('checkout gratuit explique qu aucun paiement est requis', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => startSubscriptionCheckout(
              context,
              'free',
              source: 'test-free',
            ),
            child: const Text('Choisir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Choisir'));
    await tester.pump();

    expect(
      find.text('Cette formule ne nécessite pas de paiement.'),
      findsOneWidget,
    );
  });

  testWidgets('notify affiche le message de disponibilité future', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => notifySubscriptionLaunch(
              context,
              'ilipresto_plus',
              source: 'test-notify',
            ),
            child: const Text('Notifier'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Notifier'));
    await tester.pump();

    expect(
      find.text(
        'Vous serez informé lorsque cette formule sera disponible.',
      ),
      findsOneWidget,
    );
  });

  test('prefetch désactivé ne contacte aucun service', () async {
    await prefetchSubscriptionCheckout(
      'ilipro',
      stripeEnabled: false,
      source: 'test-disabled',
    );
  });
}
