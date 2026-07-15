import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_checkout_service.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

const _plusRequest = SubscriptionActionRequest(
  action: SubscriptionActionType.checkout,
  plan: SubscriptionPlan.iliprestoPlus,
  source: 'coverage-test',
  stripeEnabled: true,
);

Widget _actionHost({
  required SubscriptionCheckoutService service,
  required SubscriptionActionRequest request,
  String label = 'Exécuter',
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async => service.handleAction(context, request),
            child: Text(label),
          ),
        ),
      ),
    ),
  );
}

Future<void> _tapAction(WidgetTester tester) async {
  await tester.tap(find.text('Exécuter'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SubscriptionCheckoutService.resetForTesting);

  testWidgets('checkout gratuit ne contacte pas Stripe', (tester) async {
    var fetchCalls = 0;
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) async {
        fetchCalls++;
        return <String, dynamic>{};
      },
    );

    await tester.pumpWidget(
      _actionHost(
        service: service,
        request: const SubscriptionActionRequest(
          action: SubscriptionActionType.checkout,
          plan: SubscriptionPlan.free,
          source: 'free-test',
          stripeEnabled: true,
        ),
      ),
    );
    await _tapAction(tester);

    expect(fetchCalls, 0);
    expect(
      find.text('Cette formule ne nécessite pas de paiement.'),
      findsOneWidget,
    );
  });

  testWidgets('checkout sans plan reste gratuit', (tester) async {
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) async => <String, dynamic>{},
    );

    await tester.pumpWidget(
      _actionHost(
        service: service,
        request: const SubscriptionActionRequest(
          action: SubscriptionActionType.checkout,
          source: 'null-plan',
          stripeEnabled: false,
        ),
      ),
    );
    await _tapAction(tester);

    expect(
      find.text('Cette formule ne nécessite pas de paiement.'),
      findsOneWidget,
    );
  });

  testWidgets('notification de lancement affiche le message attendu',
      (tester) async {
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) async => <String, dynamic>{},
    );

    await tester.pumpWidget(
      _actionHost(
        service: service,
        request: const SubscriptionActionRequest(
          action: SubscriptionActionType.notify,
          plan: SubscriptionPlan.ilipro,
          source: 'notify-test',
          stripeEnabled: false,
        ),
      ),
    );
    await _tapAction(tester);

    expect(
      find.text('Vous serez informé lorsque cette formule sera disponible.'),
      findsOneWidget,
    );
  });

  testWidgets('checkout valide transmet le plan et ouvre Stripe',
      (tester) async {
    String? callable;
    Map<String, dynamic>? payload;
    Uri? openedUri;
    var historyCalls = 0;
    final now = DateTime(2026, 7, 15, 12);
    final service = SubscriptionCheckoutService(
      clock: () => now,
      stripeDataFetcher: (name, data) async {
        callable = name;
        payload = Map<String, dynamic>.from(data);
        return <String, dynamic>{
          'checkoutUrl': 'https://checkout.stripe.com/c/pay/cs_test_123',
          'expiresAt': now.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
        };
      },
      externalLauncher: (uri) async {
        openedUri = uri;
        return true;
      },
      returnHistoryPreparer: () => historyCalls++,
    );

    await tester.pumpWidget(_actionHost(service: service, request: _plusRequest));
    await _tapAction(tester);

    expect(callable, 'createSubscriptionCheckoutSession');
    expect(payload?['plan'], 'ilipresto_plus');
    expect(payload?['subscriptionPlan'], 'ilipresto_plus');
    expect(payload?['source'], 'coverage-test');
    expect(openedUri?.host, 'checkout.stripe.com');
    expect(historyCalls, 1);
  });

  testWidgets('portail Stripe utilise le callable et la source attendus',
      (tester) async {
    String? callable;
    Map<String, dynamic>? payload;
    Uri? openedUri;
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (name, data) async {
        callable = name;
        payload = Map<String, dynamic>.from(data);
        return <String, dynamic>{
          'portalUrl': 'https://billing.stripe.com/p/session/test',
        };
      },
      externalLauncher: (uri) async {
        openedUri = uri;
        return true;
      },
      returnHistoryPreparer: () {},
    );

    await tester.pumpWidget(
      _actionHost(
        service: service,
        request: const SubscriptionActionRequest(
          action: SubscriptionActionType.manage,
          source: 'account-manage',
          stripeEnabled: true,
        ),
      ),
    );
    await _tapAction(tester);

    expect(callable, 'createSubscriptionPortalSession');
    expect(payload, <String, dynamic>{'source': 'account-manage'});
    expect(openedUri?.host, 'billing.stripe.com');
  });

  testWidgets('URL non Stripe est refusée sans lancer le navigateur',
      (tester) async {
    var launcherCalls = 0;
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) async => <String, dynamic>{
        'url': 'https://example.com/faux-checkout',
      },
      externalLauncher: (_) async {
        launcherCalls++;
        return true;
      },
    );

    await tester.pumpWidget(_actionHost(service: service, request: _plusRequest));
    await _tapAction(tester);

    expect(launcherCalls, 0);
    expect(
      find.text(
        'L’adresse de paiement retournée n’est pas une URL Stripe sécurisée.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('schéma HTTP Stripe est refusé', (tester) async {
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) async => <String, dynamic>{
        'url': 'http://checkout.stripe.com/test',
      },
      externalLauncher: (_) async => true,
    );

    await tester.pumpWidget(_actionHost(service: service, request: _plusRequest));
    await _tapAction(tester);

    expect(
      find.text(
        'L’adresse de paiement retournée n’est pas une URL Stripe sécurisée.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('échec du lanceur affiche une erreur explicite', (tester) async {
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) async => <String, dynamic>{
        'url': 'https://stripe.com/checkout/test',
      },
      externalLauncher: (_) async => false,
      returnHistoryPreparer: () {},
    );

    await tester.pumpWidget(_actionHost(service: service, request: _plusRequest));
    await _tapAction(tester);

    expect(find.text('Impossible d’ouvrir la page Stripe.'), findsOneWidget);
  });

  testWidgets('réponse sans URL affiche URL introuvable', (tester) async {
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) async => <String, dynamic>{'ok': true},
    );

    await tester.pumpWidget(_actionHost(service: service, request: _plusRequest));
    await _tapAction(tester);

    expect(find.text('URL Stripe introuvable.'), findsOneWidget);
  });

  testWidgets('URL de session imbriquée est reconnue', (tester) async {
    Uri? openedUri;
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) async => <String, dynamic>{
        'session': <String, dynamic>{
          'url': 'https://checkout.stripe.com/c/pay/nested',
        },
      },
      externalLauncher: (uri) async {
        openedUri = uri;
        return true;
      },
      returnHistoryPreparer: () {},
    );

    await tester.pumpWidget(_actionHost(service: service, request: _plusRequest));
    await _tapAction(tester);

    expect(openedUri?.path, contains('nested'));
  });

  testWidgets('erreur générique reprend le message de configuration',
      (tester) async {
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) async => throw StateError('offline'),
    );

    await tester.pumpWidget(
      _actionHost(
        service: service,
        request: const SubscriptionActionRequest(
          action: SubscriptionActionType.checkout,
          plan: SubscriptionPlan.ilipro,
          source: 'disabled-test',
          stripeEnabled: false,
        ),
      ),
    );
    await _tapAction(tester);

    expect(
      find.text('Stripe n’est pas activé dans la configuration abonnement.'),
      findsOneWidget,
    );
  });

  test('prefetch gratuit ne contacte pas le backend', () async {
    var calls = 0;
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) async {
        calls++;
        return <String, dynamic>{};
      },
    );

    await service.prefetchCheckout(SubscriptionPlan.free);
    expect(calls, 0);
  });

  test('prefetch invalide absorbe l erreur et peut être retenté', () async {
    var calls = 0;
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) async {
        calls++;
        throw StateError('offline');
      },
    );

    await service.prefetchCheckout(SubscriptionPlan.ilipro);
    await service.prefetchCheckout(SubscriptionPlan.ilipro);
    expect(calls, 2);
  });

  testWidgets('prefetch valide alimente le cache du checkout', (tester) async {
    final now = DateTime(2026, 7, 15, 12);
    var fetchCalls = 0;
    var launchCalls = 0;
    final service = SubscriptionCheckoutService(
      clock: () => now,
      stripeDataFetcher: (_, __) async {
        fetchCalls++;
        return <String, dynamic>{
          'url': 'https://checkout.stripe.com/c/pay/cached',
          'expires_at': now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
        };
      },
      externalLauncher: (_) async {
        launchCalls++;
        return true;
      },
      returnHistoryPreparer: () {},
    );

    await service.prefetchCheckout(SubscriptionPlan.iliprestoPlus);
    await service.prefetchCheckout(SubscriptionPlan.iliprestoPlus);
    expect(fetchCalls, 1);

    await tester.pumpWidget(_actionHost(service: service, request: _plusRequest));
    await _tapAction(tester);

    expect(fetchCalls, 1);
    expect(launchCalls, 1);
  });

  testWidgets('cache proche de l expiration est renouvelé', (tester) async {
    var now = DateTime(2026, 7, 15, 12);
    var fetchCalls = 0;
    final service = SubscriptionCheckoutService(
      clock: () => now,
      stripeDataFetcher: (_, __) async {
        fetchCalls++;
        final expiry = fetchCalls == 1
            ? now.add(const Duration(seconds: 10))
            : now.add(const Duration(minutes: 5));
        return <String, dynamic>{
          'url': 'https://checkout.stripe.com/c/pay/renewed',
          'expiresAt': expiry.millisecondsSinceEpoch,
        };
      },
      externalLauncher: (_) async => true,
      returnHistoryPreparer: () {},
    );

    await service.prefetchCheckout(SubscriptionPlan.iliprestoPlus);
    now = now.add(const Duration(seconds: 1));
    await tester.pumpWidget(_actionHost(service: service, request: _plusRequest));
    await _tapAction(tester);

    expect(fetchCalls, 2);
  });

  testWidgets('expiration exprimée en secondes est normalisée', (tester) async {
    final now = DateTime(2026, 7, 15, 12);
    var fetchCalls = 0;
    final service = SubscriptionCheckoutService(
      clock: () => now,
      stripeDataFetcher: (_, __) async {
        fetchCalls++;
        return <String, dynamic>{
          'url': 'https://checkout.stripe.com/c/pay/seconds',
          'expiresAt': now.add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000,
        };
      },
      externalLauncher: (_) async => true,
      returnHistoryPreparer: () {},
    );

    await service.prefetchCheckout(SubscriptionPlan.iliprestoPlus);
    await tester.pumpWidget(_actionHost(service: service, request: _plusRequest));
    await _tapAction(tester);

    expect(fetchCalls, 1);
  });

  testWidgets('une ouverture concurrente est bloquée', (tester) async {
    final response = Completer<Map<String, dynamic>>();
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) => response.future,
      externalLauncher: (_) async => true,
      returnHistoryPreparer: () {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    unawaited(service.handleAction(context, _plusRequest));
                  },
                  child: const Text('Premier'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await service.handleAction(context, _plusRequest);
                  },
                  child: const Text('Second'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Premier'));
    await tester.pump();
    await tester.tap(find.text('Second'));
    await tester.pump();

    expect(find.text('Ouverture de Stripe déjà en cours…'), findsOneWidget);

    response.complete(<String, dynamic>{
      'url': 'https://checkout.stripe.com/c/pay/concurrent',
    });
    await tester.pump(const Duration(milliseconds: 100));
  });

  test('exception Stripe expose son message', () {
    const error = SubscriptionCheckoutException('message test');
    expect(error.message, 'message test');
    expect(error.toString(), 'message test');
  });
}
