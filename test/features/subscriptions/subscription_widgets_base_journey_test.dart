import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

SubscriptionAppConfig _enabledConfig() {
  return const SubscriptionAppConfig(
    subscriptionSectionEnabled: true,
    subscriptionsPrepared: true,
    stripeEnabled: false,
    freeAccessMode: false,
  );
}

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: child,
      ),
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
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1200, 3200);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('la section active présente l abonnement gratuit par défaut',
      (tester) async {
    final service = _StaticSubscriptionConfigService(_enabledConfig());

    await tester.pumpWidget(
      _app(SubscriptionSection(userId: 'user-section', service: service)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Mon abonnement iliprestō'), findsOneWidget);
    expect(find.text('Gratuit'), findsOneWidget);
    expect(find.text('OFFRE ACTUELLE'), findsOneWidget);
    expect(find.text('Découvrir les autres offres'), findsOneWidget);
    expect(
      find.text(
        'Sans engagement, vous pouvez changer de formule à tout moment.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('la page détails bascule des offres particuliers vers pro',
      (tester) async {
    final service = _StaticSubscriptionConfigService(_enabledConfig());

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionDetailsPage(
          userId: 'user-details',
          service: service,
        ),
      ),
    );
    await tester.pump();

    final particuliersSelector = find.widgetWithText(InkWell, 'Particuliers');
    final proSelector = find.widgetWithText(InkWell, 'Pro');

    expect(find.text('Découvrez les offres'), findsOneWidget);
    expect(particuliersSelector, findsOneWidget);
    expect(proSelector, findsOneWidget);
    expect(find.text('Gratuit'), findsNWidgets(2));
    expect(find.text('iliprestō+'), findsOneWidget);
    expect(find.text('Choisir iliprestō+'), findsOneWidget);
    expect(find.text('Choisir ilipro'), findsNothing);

    await tester.tap(proSelector);
    await tester.pumpAndSettle();

    expect(find.text('Gratuit Pro'), findsOneWidget);
    expect(find.text('0 €/mois'), findsOneWidget);
    expect(find.text('ilipro'), findsOneWidget);
    expect(find.text('Choisir ilipro'), findsOneWidget);
    expect(find.text('Choisir iliprestō+'), findsNothing);

    await tester.tap(particuliersSelector);
    await tester.pumpAndSettle();

    expect(find.text('Choisir iliprestō+'), findsOneWidget);
    expect(find.text('Choisir ilipro'), findsNothing);
  });
}
