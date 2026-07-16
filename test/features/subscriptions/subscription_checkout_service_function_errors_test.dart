import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_checkout_service.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

const _checkoutRequest = SubscriptionActionRequest(
  action: SubscriptionActionType.checkout,
  plan: SubscriptionPlan.iliprestoPlus,
  source: 'function-error-coverage',
  stripeEnabled: true,
);

Widget _host(SubscriptionCheckoutService service) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => service.handleAction(context, _checkoutRequest),
            child: const Text('Ouvrir Stripe'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _trigger(
  WidgetTester tester,
  FirebaseFunctionsException exception,
) async {
  final service = SubscriptionCheckoutService(
    stripeDataFetcher: (_, __) async => throw exception,
  );

  await tester.pumpWidget(_host(service));
  await tester.tap(find.text('Ouvrir Stripe'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SubscriptionCheckoutService.resetForTesting);

  testWidgets('affiche le message explicite retourné par Cloud Functions',
      (tester) async {
    await _trigger(
      tester,
      FirebaseFunctionsException(
        code: 'internal',
        message: 'Paiement momentanément indisponible.',
      ),
    );

    expect(
      find.text('Paiement momentanément indisponible.'),
      findsOneWidget,
    );
  });

  testWidgets('traduit une erreur unauthenticated', (tester) async {
    await _trigger(
      tester,
      FirebaseFunctionsException(code: 'unauthenticated', message: ''),
    );

    expect(
      find.text('Connectez-vous pour gérer votre abonnement.'),
      findsOneWidget,
    );
  });

  testWidgets('traduit une erreur permission-denied', (tester) async {
    await _trigger(
      tester,
      FirebaseFunctionsException(code: 'permission-denied', message: ''),
    );

    expect(
      find.text('Cette opération Stripe n’est pas autorisée.'),
      findsOneWidget,
    );
  });

  testWidgets('traduit une erreur resource-exhausted', (tester) async {
    await _trigger(
      tester,
      FirebaseFunctionsException(code: 'resource-exhausted', message: ''),
    );

    expect(
      find.text('Stripe reçoit trop de demandes. Réessayez dans un instant.'),
      findsOneWidget,
    );
  });
}
