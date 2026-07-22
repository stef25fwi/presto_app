import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_checkout_service.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

const _request = SubscriptionActionRequest(
  action: SubscriptionActionType.checkout,
  plan: SubscriptionPlan.iliprestoPlus,
  source: 'critical-payment-coverage',
  stripeEnabled: true,
);

Widget _host(SubscriptionCheckoutService service) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () async => service.handleAction(context, _request),
          child: const Text('Ouvrir Stripe'),
        ),
      ),
    ),
  );
}

Future<void> _runAction(WidgetTester tester) async {
  await tester.tap(find.text('Ouvrir Stripe'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SubscriptionCheckoutService.resetForTesting();
  });

  testWidgets(
    'utilise la préparation historique et le lanceur URL par défaut',
    (tester) async {
      const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
      final launcherCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launcherChannel, (call) async {
        launcherCalls.add(call);
        return true;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(launcherChannel, null);
      });

      final service = SubscriptionCheckoutService(
        stripeDataFetcher: (_, __) async => <String, dynamic>{
          'url': 'https://checkout.stripe.com/c/pay/default-launcher',
        },
      );

      await tester.pumpWidget(_host(service));
      await _runAction(tester);

      expect(launcherCalls, isNotEmpty);
      expect(
        launcherCalls.any((call) => call.method.toLowerCase().contains('launch')),
        isTrue,
      );
      expect(find.text('Impossible d’ouvrir la page Stripe.'), findsNothing);
    },
  );

  testWidgets('convertit la réponse du callable Firebase par défaut',
      (tester) async {
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    const functionsChannel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_functions_platform_interface.'
      'CloudFunctionsHostApi.call',
      StandardMessageCodec(),
    );
    final calls = <Object?>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler<Object?>(
      functionsChannel,
      (message) async {
        calls.add(message);
        return <Object?>[
          <String, Object?>{
            'url': 'https://checkout.stripe.com/c/pay/default-functions',
          },
        ];
      },
    );
    addTearDown(() {
      messenger.setMockDecodedMessageHandler<Object?>(functionsChannel, null);
    });

    Uri? openedUri;
    final service = SubscriptionCheckoutService(
      externalLauncher: (uri) async {
        openedUri = uri;
        return true;
      },
      returnHistoryPreparer: () {},
    );

    await tester.pumpWidget(_host(service));
    await _runAction(tester);

    expect(calls, hasLength(1));
    final envelope = calls.single! as List<Object?>;
    final arguments = envelope.single! as Map<Object?, Object?>;
    expect(arguments['functionName'], 'createSubscriptionCheckoutSession');
    expect(arguments['region'], 'europe-west1');
    expect(
      arguments['parameters'],
      containsPair('plan', 'ilipresto_plus'),
    );
    expect(openedUri?.host, 'checkout.stripe.com');
    expect(find.text('Impossible de lancer Stripe pour le moment.'), findsNothing);
  });
}
