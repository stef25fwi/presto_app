import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/operating_mode/app_operating_mode.dart';
import 'package:presto_app/features/subscriptions/subscription_action_placeholders.dart';
import 'package:presto_app/features/subscriptions/subscription_checkout_service.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

class _FakeCheckoutService extends SubscriptionCheckoutService {
  final List<SubscriptionActionRequest> requests =
      <SubscriptionActionRequest>[];

  @override
  Future<void> handleAction(
    BuildContext context,
    SubscriptionActionRequest request,
  ) async {
    requests.add(request);
  }
}

void main() {
  late _FakeCheckoutService checkout;

  setUp(() {
    resetSubscriptionActionOverrides();
    checkout = _FakeCheckoutService();
    subscriptionCheckoutServiceOverride = checkout;
  });

  tearDown(resetSubscriptionActionOverrides);

  Widget actionButton(Future<void> Function(BuildContext context) action) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => action(context),
            child: const Text('Action'),
          ),
        ),
      ),
    );
  }

  test('exécute directement le résolveur commercial injecté', () async {
    var calls = 0;
    subscriptionCommercialModeResolverOverride = () async {
      calls += 1;
      return true;
    };

    expect(await resolveSubscriptionCommercialModeForTesting(), isTrue);
    expect(calls, 1);
  });

  test(
    'résout le mode commercial avec le service d exploitation injecté',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('app_config').doc('legal').set(
        const <String, dynamic>{'operatingMode': 'commercial'},
      );
      subscriptionOperatingModeServiceFactory = () =>
          AppOperatingModeService(firestore: firestore);

      expect(await resolveSubscriptionCommercialModeForTesting(), isTrue);
    },
  );

  testWidgets('checkout payant passe au service en mode commercial', (
    tester,
  ) async {
    var resolverCalls = 0;
    subscriptionCommercialModeResolverOverride = () async {
      resolverCalls += 1;
      return true;
    };
    await tester.pumpWidget(
      actionButton(
        (context) => startSubscriptionCheckout(
          context,
          'ilipresto_plus',
          stripeEnabled: true,
          source: 'coverage-checkout',
        ),
      ),
    );

    await tester.tap(find.text('Action'));
    await tester.pumpAndSettle();

    expect(resolverCalls, 1);
    expect(checkout.requests, hasLength(1));
    final request = checkout.requests.single;
    expect(request.action, SubscriptionActionType.checkout);
    expect(request.plan, SubscriptionPlan.iliprestoPlus);
    expect(request.source, 'coverage-checkout');
    expect(request.stripeEnabled, isTrue);
  });

  testWidgets('checkout payant reste fermé en bêta gratuite', (tester) async {
    subscriptionCommercialModeResolverOverride = () async => false;
    await tester.pumpWidget(
      actionButton(
        (context) =>
            startSubscriptionCheckout(context, 'ilipro', stripeEnabled: true),
      ),
    );

    await tester.tap(find.text('Action'));
    await tester.pump();

    expect(checkout.requests, isEmpty);
    expect(
      find.text(
        'Ilipresto est actuellement en bêta gratuite. Aucun abonnement ou paiement n’est actif.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('gestion Stripe passe au service en mode commercial', (
    tester,
  ) async {
    subscriptionCommercialModeResolverOverride = () async => true;
    await tester.pumpWidget(
      actionButton(
        (context) => openSubscriptionManagement(
          context,
          stripeEnabled: true,
          source: 'coverage-management',
        ),
      ),
    );

    await tester.tap(find.text('Action'));
    await tester.pumpAndSettle();

    expect(checkout.requests, hasLength(1));
    final request = checkout.requests.single;
    expect(request.action, SubscriptionActionType.manage);
    expect(request.plan, isNull);
    expect(request.source, 'coverage-management');
    expect(request.stripeEnabled, isTrue);
  });

  testWidgets('gestion Stripe désactivée affiche le message bêta', (
    tester,
  ) async {
    await tester.pumpWidget(
      actionButton(
        (context) => openSubscriptionManagement(context, stripeEnabled: false),
      ),
    );

    await tester.tap(find.text('Action'));
    await tester.pump();

    expect(checkout.requests, isEmpty);
    expect(
      find.text(
        'Ilipresto est actuellement en bêta gratuite. Aucun abonnement ou paiement n’est actif.',
      ),
      findsOneWidget,
    );
  });
}
