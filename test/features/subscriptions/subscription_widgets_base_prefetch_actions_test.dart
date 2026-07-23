import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_action_placeholders.dart';
import 'package:presto_app/features/subscriptions/subscription_checkout_service.dart';
import 'package:presto_app/features/subscriptions/subscription_config_service.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';
import 'package:presto_app/features/subscriptions/subscription_widgets_base.dart';

class _StaticSubscriptionConfigService extends SubscriptionConfigService {
  _StaticSubscriptionConfigService(this.config)
      : super(firestore: FakeFirebaseFirestore());

  final SubscriptionAppConfig config;

  @override
  Stream<SubscriptionAppConfig> watchConfig({bool ensureExists = false}) {
    return Stream<SubscriptionAppConfig>.value(config);
  }
}

const _stripeConfig = SubscriptionAppConfig(
  subscriptionSectionEnabled: true,
  subscriptionsPrepared: true,
  stripeEnabled: true,
  freeAccessMode: false,
);

const _notifyConfig = SubscriptionAppConfig(
  subscriptionSectionEnabled: true,
  subscriptionsPrepared: true,
  stripeEnabled: false,
  freeAccessMode: false,
);

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    SubscriptionCheckoutService.resetForTesting();
    subscriptionCommercialModeResolverOverride = () async => true;
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1200, 3200);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    SubscriptionCheckoutService.resetForTesting();
    resetSubscriptionActionOverrides();
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('précharge Stripe depuis la section abonnement active',
      (tester) async {
    final service = _StaticSubscriptionConfigService(_stripeConfig);

    await tester.pumpWidget(
      _app(
        SubscriptionSection(
          userId: 'prefetch-section-user',
          service: service,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Mon abonnement iliprestō'), findsOneWidget);
    expect(find.text('Découvrir les autres offres'), findsOneWidget);
    expect(find.text('Gratuit'), findsOneWidget);
  });

  testWidgets('précharge les offres Stripe des deux audiences', (tester) async {
    final service = _StaticSubscriptionConfigService(_stripeConfig);

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionDetailsPage(
          userId: 'prefetch-details-user',
          service: service,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final particuliersSelector = find.widgetWithText(InkWell, 'Particuliers');
    final proSelector = find.widgetWithText(InkWell, 'Pro');

    expect(particuliersSelector, findsOneWidget);
    expect(proSelector, findsOneWidget);
    expect(find.text('Choisir iliprestō+'), findsOneWidget);

    await tester.tap(proSelector);
    await tester.pumpAndSettle();

    expect(find.text('Choisir ilipro'), findsOneWidget);

    await tester.tap(particuliersSelector);
    await tester.pumpAndSettle();

    expect(find.text('Choisir iliprestō+'), findsOneWidget);
  });

  testWidgets('sans Stripe la sélection demande une notification',
      (tester) async {
    await tester.pumpWidget(
      _app(
        const SubscriptionPlanTabs(
          config: _notifyConfig,
          userState: AppUserSubscriptionState.free(),
        ),
      ),
    );

    await tester.tap(find.text('Choisir iliprestō+'));
    await tester.pump();

    expect(
      find.text(
        'Vous serez informé lorsque cette formule sera disponible.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('avec Stripe la sélection tente le checkout sécurisé',
      (tester) async {
    await tester.pumpWidget(
      _app(
        const SubscriptionPlanTabs(
          config: _stripeConfig,
          userState: AppUserSubscriptionState.free(),
          audience: OfferAudience.pro,
        ),
      ),
    );

    await tester.tap(find.text('Choisir ilipro'));
    await tester.pump();

    expect(find.text('Ouverture sécurisée de Stripe…'), findsOneWidget);
  });
}
