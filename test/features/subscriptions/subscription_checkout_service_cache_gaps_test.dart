import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_checkout_service.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

const _request = SubscriptionActionRequest(
  action: SubscriptionActionType.checkout,
  plan: SubscriptionPlan.iliprestoPlus,
  source: 'cache-gap-coverage',
  stripeEnabled: true,
);

Widget _host(SubscriptionCheckoutService service) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => service.handleAction(context, _request),
          child: const Text('Ouvrir Stripe'),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Ouvrir Stripe'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SubscriptionCheckoutService.resetForTesting);

  test('deux prefetch concurrents partagent la même requête backend', () async {
    final response = Completer<Map<String, dynamic>>();
    var calls = 0;
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) {
        calls++;
        return response.future;
      },
    );

    final first = service.prefetchCheckout(SubscriptionPlan.iliprestoPlus);
    await Future<void>.delayed(Duration.zero);
    final second = service.prefetchCheckout(SubscriptionPlan.iliprestoPlus);

    expect(calls, 1);
    response.complete(<String, dynamic>{
      'url': 'https://checkout.stripe.com/c/pay/shared-prefetch',
    });
    await Future.wait<void>(<Future<void>>[first, second]);
    expect(calls, 1);
  });

  testWidgets('checkout attend le prefetch en cours sans second appel backend',
      (tester) async {
    final response = Completer<Map<String, dynamic>>();
    var fetchCalls = 0;
    var launchCalls = 0;
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) {
        fetchCalls++;
        return response.future;
      },
      externalLauncher: (_) async {
        launchCalls++;
        return true;
      },
      returnHistoryPreparer: () {},
    );

    final prefetch = service.prefetchCheckout(SubscriptionPlan.iliprestoPlus);
    await Future<void>.delayed(Duration.zero);
    await tester.pumpWidget(_host(service));
    await tester.tap(find.text('Ouvrir Stripe'));
    await tester.pump();

    expect(fetchCalls, 1);
    response.complete(<String, dynamic>{
      'url': 'https://checkout.stripe.com/c/pay/pending-prefetch',
    });
    await prefetch;
    await tester.pump(const Duration(milliseconds: 100));

    expect(fetchCalls, 1);
    expect(launchCalls, 1);
  });

  testWidgets('expiration de secours renouvelle le cache après vingt minutes',
      (tester) async {
    var now = DateTime(2026, 7, 17, 12);
    var calls = 0;
    final service = SubscriptionCheckoutService(
      clock: () => now,
      stripeDataFetcher: (_, __) async {
        calls++;
        return <String, dynamic>{
          'url': 'https://checkout.stripe.com/c/pay/fallback-$calls',
        };
      },
      externalLauncher: (_) async => true,
      returnHistoryPreparer: () {},
    );

    await service.prefetchCheckout(SubscriptionPlan.iliprestoPlus);
    expect(calls, 1);

    now = now.add(const Duration(minutes: 20));
    await tester.pumpWidget(_host(service));
    await _open(tester);

    expect(calls, 2);
  });

  for (final entry in <MapEntry<String, String>>[
    const MapEntry('paymentUrl', 'payment'),
    const MapEntry('sessionUrl', 'session'),
  ]) {
    testWidgets('reconnaît ${entry.key} dans la réponse Stripe',
        (tester) async {
      Uri? openedUri;
      final service = SubscriptionCheckoutService(
        stripeDataFetcher: (_, __) async => <String, dynamic>{
          entry.key: 'https://checkout.stripe.com/c/pay/${entry.value}',
        },
        externalLauncher: (uri) async {
          openedUri = uri;
          return true;
        },
        returnHistoryPreparer: () {},
      );

      await tester.pumpWidget(_host(service));
      await _open(tester);

      expect(openedUri?.path, contains(entry.value));
    });
  }

  test('prefetch avec URL non fiable est absorbé puis retenté', () async {
    var calls = 0;
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) async {
        calls++;
        return <String, dynamic>{'url': 'https://example.com/not-stripe'};
      },
    );

    await service.prefetchCheckout(SubscriptionPlan.ilipro);
    await service.prefetchCheckout(SubscriptionPlan.ilipro);

    expect(calls, 2);
  });
}
