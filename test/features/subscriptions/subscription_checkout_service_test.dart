import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_checkout_service.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SubscriptionCheckoutService.resetForTesting);

  Widget actionApp({
    required SubscriptionCheckoutService service,
    required SubscriptionActionRequest request,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => service.handleAction(context, request),
            child: const Text('Agir'),
          ),
        ),
      ),
    );
  }

  Future<void> trigger(
    WidgetTester tester, {
    required SubscriptionCheckoutService service,
    required SubscriptionActionRequest request,
    bool settle = true,
  }) async {
    await tester.pumpWidget(actionApp(service: service, request: request));
    await tester.tap(find.text('Agir'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  SubscriptionActionRequest checkout({
    SubscriptionPlan? plan = SubscriptionPlan.iliprestoPlus,
    bool stripeEnabled = true,
    String source = 'test-checkout',
  }) {
    return SubscriptionActionRequest(
      action: SubscriptionActionType.checkout,
      plan: plan,
      source: source,
      stripeEnabled: stripeEnabled,
    );
  }

  testWidgets('une formule absente ou gratuite ne lance pas Stripe', (
    tester,
  ) async {
    var fetches = 0;
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) async {
        fetches += 1;
        return <String, dynamic>{};
      },
    );

    await trigger(
      tester,
      service: service,
      request: checkout(plan: null),
    );
    expect(
      find.text('Cette formule ne nécessite pas de paiement.'),
      findsOneWidget,
    );

    await trigger(
      tester,
      service: service,
      request: checkout(plan: SubscriptionPlan.free),
    );
    expect(fetches, 0);
  });

  testWidgets('notify affiche la confirmation sans appel distant', (
    tester,
  ) async {
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) => throw StateError('ne doit pas être appelé'),
    );

    await trigger(
      tester,
      service: service,
      request: const SubscriptionActionRequest(
        action: SubscriptionActionType.notify,
        source: 'test-notify',
        stripeEnabled: false,
      ),
    );

    expect(
      find.text(
        'Vous serez informé lorsque cette formule sera disponible.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('checkout transmet le plan et ouvre une URL Stripe', (
    tester,
  ) async {
    String? callable;
    Map<String, dynamic>? payload;
    Uri? launched;
    var prepared = 0;
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (name, data) async {
        callable = name;
        payload = data;
        return <String, dynamic>{
          'url': 'https://checkout.stripe.com/c/pay_test',
          'expiresAt': 2000000000,
        };
      },
      externalLauncher: (uri) async {
        launched = uri;
        return true;
      },
      returnHistoryPreparer: () => prepared += 1,
      clock: () => DateTime.fromMillisecondsSinceEpoch(1900000000000),
    );

    await trigger(
      tester,
      service: service,
      request: checkout(
        plan: SubscriptionPlan.iliprestoPlus,
        source: 'pricing-card',
      ),
    );

    expect(callable, 'createSubscriptionCheckoutSession');
    expect(payload?['plan'], 'ilipresto_plus');
    expect(payload?['subscriptionPlan'], 'ilipresto_plus');
    expect(payload?['source'], 'pricing-card');
    expect(launched?.host, 'checkout.stripe.com');
    expect(prepared, 1);
    expect(find.text('Ouverture sécurisée de Stripe…'), findsNothing);
  });

  testWidgets('manage utilise le portail Stripe et son payload', (tester) async {
    String? callable;
    Map<String, dynamic>? payload;
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (name, data) async {
        callable = name;
        payload = data;
        return <String, dynamic>{
          'portalUrl': 'https://billing.stripe.com/p/session_test',
        };
      },
      externalLauncher: (_) async => true,
      returnHistoryPreparer: () {},
    );

    await trigger(
      tester,
      service: service,
      request: const SubscriptionActionRequest(
        action: SubscriptionActionType.manage,
        source: 'account-page',
        stripeEnabled: true,
      ),
    );

    expect(callable, 'createSubscriptionPortalSession');
    expect(payload, <String, dynamic>{'source': 'account-page'});
  });

  test('prefetch gratuit est ignoré et une erreur est avalée', () async {
    var fetches = 0;
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) async {
        fetches += 1;
        throw StateError('indisponible');
      },
    );

    await service.prefetchCheckout(SubscriptionPlan.free);
    await service.prefetchCheckout(SubscriptionPlan.ilipro);

    expect(fetches, 1);
  });

  testWidgets('un prefetch valide alimente le cache du checkout', (
    tester,
  ) async {
    var fetches = 0;
    var launches = 0;
    final now = DateTime(2026, 7, 15, 12);
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, payload) async {
        fetches += 1;
        expect(payload['source'], anyOf('warmup', 'checkout-after-prefetch'));
        return <String, dynamic>{
          'checkoutUrl': 'https://stripe.com/pay/cache',
          'expires_at': now.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
        };
      },
      externalLauncher: (_) async {
        launches += 1;
        return true;
      },
      returnHistoryPreparer: () {},
      clock: () => now,
    );

    await service.prefetchCheckout(
      SubscriptionPlan.iliprestoPlus,
      source: 'warmup',
    );
    await trigger(
      tester,
      service: service,
      request: checkout(source: 'checkout-after-prefetch'),
    );

    expect(fetches, 1);
    expect(launches, 1);
  });

  test('deux prefetch concurrents partagent la même requête', () async {
    final completer = Completer<Map<String, dynamic>>();
    var fetches = 0;
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) {
        fetches += 1;
        return completer.future;
      },
      clock: () => DateTime(2026, 7, 15, 12),
    );

    final first = service.prefetchCheckout(SubscriptionPlan.ilipro);
    final second = service.prefetchCheckout(SubscriptionPlan.ilipro);
    expect(fetches, 1);

    completer.complete(<String, dynamic>{
      'paymentUrl': 'https://stripe.com/pay/shared',
      'expiresAt': 2000000000,
    });
    await Future.wait(<Future<void>>[first, second]);
    expect(fetches, 1);
  });

  testWidgets('un cache presque expiré est remplacé', (tester) async {
    var now = DateTime(2026, 7, 15, 12);
    var fetches = 0;
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) async {
        fetches += 1;
        return <String, dynamic>{
          'sessionUrl': 'https://stripe.com/pay/$fetches',
          'expiresAt': fetches == 1
              ? now.add(const Duration(seconds: 10)).millisecondsSinceEpoch
              : now.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
        };
      },
      externalLauncher: (_) async => true,
      returnHistoryPreparer: () {},
      clock: () => now,
    );

    await service.prefetchCheckout(SubscriptionPlan.ilipro);
    now = now.add(const Duration(seconds: 1));
    await trigger(
      tester,
      service: service,
      request: checkout(plan: SubscriptionPlan.ilipro),
    );

    expect(fetches, 2);
  });

  testWidgets('un prefetch en cours est attendu par le checkout', (
    tester,
  ) async {
    final completer = Completer<Map<String, dynamic>>();
    var fetches = 0;
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) {
        fetches += 1;
        return completer.future;
      },
      externalLauncher: (_) async => true,
      returnHistoryPreparer: () {},
      clock: () => DateTime(2026, 7, 15, 12),
    );

    final prefetch = service.prefetchCheckout(SubscriptionPlan.ilipro);
    await trigger(
      tester,
      service: service,
      request: checkout(plan: SubscriptionPlan.ilipro),
      settle: false,
    );
    expect(find.text('Ouverture sécurisée de Stripe…'), findsNothing);

    completer.complete(<String, dynamic>{
      'url': 'https://stripe.com/pay/pending',
      'expiresAt': 2000000000,
    });
    await prefetch;
    await tester.pumpAndSettle();
    expect(fetches, 1);
  });

  testWidgets('une seconde action est bloquée pendant l ouverture', (
    tester,
  ) async {
    final completer = Completer<Map<String, dynamic>>();
    final service = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) => completer.future,
      externalLauncher: (_) async => true,
      returnHistoryPreparer: () {},
    );
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold(body: Text('Prêt'));
          },
        ),
      ),
    );

    final first = service.handleAction(context, checkout());
    await tester.pump();
    await service.handleAction(context, checkout(plan: SubscriptionPlan.ilipro));
    await tester.pump();
    expect(find.text('Ouverture de Stripe déjà en cours…'), findsOneWidget);

    completer.complete(<String, dynamic>{
      'url': 'https://stripe.com/pay/first',
    });
    await first;
    await tester.pumpAndSettle();
  });

  for (final entry in <String, Map<String, dynamic>>{
    'url': <String, dynamic>{'url': 'https://stripe.com/pay/url'},
    'checkoutUrl': <String, dynamic>{
      'checkoutUrl': 'https://stripe.com/pay/checkout'
    },
    'paymentUrl': <String, dynamic>{
      'paymentUrl': 'https://stripe.com/pay/payment'
    },
    'sessionUrl': <String, dynamic>{
      'sessionUrl': 'https://stripe.com/pay/session'
    },
    'portalUrl': <String, dynamic>{
      'portalUrl': 'https://stripe.com/pay/portal'
    },
    'session.url': <String, dynamic>{
      'session': <String, dynamic>{'url': 'https://stripe.com/pay/nested'},
    },
  }.entries) {
    testWidgets('extrait une URL Stripe depuis ${entry.key}', (tester) async {
      Uri? launched;
      final service = SubscriptionCheckoutService(
        stripeDataFetcher: (_, __) async => entry.value,
        externalLauncher: (uri) async {
          launched = uri;
          return true;
        },
        returnHistoryPreparer: () {},
      );

      await trigger(
        tester,
        service: service,
        request: const SubscriptionActionRequest(
          action: SubscriptionActionType.manage,
          source: 'extract-url',
          stripeEnabled: true,
        ),
      );

      expect(launched?.host, 'stripe.com');
    });
  }

  for (final invalidUrl in <String>[
    'http://stripe.com/pay/insecure',
    'https://evilstripe.com/pay/fake',
    'not a url',
  ]) {
    testWidgets('refuse l URL non fiable $invalidUrl', (tester) async {
      final service = SubscriptionCheckoutService(
        stripeDataFetcher: (_, __) async => <String, dynamic>{
          'url': invalidUrl,
        },
        externalLauncher: (_) async => true,
        returnHistoryPreparer: () {},
      );

      await trigger(
        tester,
        service: service,
        request: checkout(),
      );

      expect(
        find.text(
          'L’adresse de paiement retournée n’est pas une URL Stripe sécurisée.',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('signale une URL absente ou un lanceur défaillant', (
    tester,
  ) async {
    final missing = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) async => <String, dynamic>{},
    );
    await trigger(tester, service: missing, request: checkout());
    expect(find.text('URL Stripe introuvable.'), findsOneWidget);

    SubscriptionCheckoutService.resetForTesting();
    final closed = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) async => <String, dynamic>{
        'url': 'https://stripe.com/pay/closed',
      },
      externalLauncher: (_) async => false,
      returnHistoryPreparer: () {},
    );
    await trigger(tester, service: closed, request: checkout());
    expect(find.text('Impossible d’ouvrir la page Stripe.'), findsOneWidget);
  });

  for (final expectation in <String, String>{
    'unauthenticated': 'Connectez-vous pour gérer votre abonnement.',
    'permission-denied': 'Cette opération Stripe n’est pas autorisée.',
    'resource-exhausted':
        'Stripe reçoit trop de demandes. Réessayez dans un instant.',
    'unavailable': 'Stripe est temporairement indisponible.',
  }.entries) {
    testWidgets('traduit l erreur Functions ${expectation.key}', (
      tester,
    ) async {
      final service = SubscriptionCheckoutService(
        stripeDataFetcher: (_, __) => throw FirebaseFunctionsException(
          code: expectation.key,
          message: '',
        ),
      );

      await trigger(tester, service: service, request: checkout());
      expect(find.text(expectation.value), findsOneWidget);
    });
  }

  testWidgets('préfère le message Functions puis le fallback générique', (
    tester,
  ) async {
    final remote = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) => throw FirebaseFunctionsException(
        code: 'unknown',
        message: '  Message Stripe distant  ',
      ),
    );
    await trigger(tester, service: remote, request: checkout());
    expect(find.text('Message Stripe distant'), findsOneWidget);

    SubscriptionCheckoutService.resetForTesting();
    final generic = SubscriptionCheckoutService(
      stripeDataFetcher: (_, __) => throw StateError('inattendu'),
    );
    await trigger(
      tester,
      service: generic,
      request: checkout(stripeEnabled: false),
    );
    expect(
      find.text('Stripe n’est pas activé dans la configuration abonnement.'),
      findsOneWidget,
    );
  });

  test('SubscriptionCheckoutException expose son message', () {
    const error = SubscriptionCheckoutException('échec');
    expect(error.message, 'échec');
    expect(error.toString(), 'échec');
  });
}
