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
    final service = _StaticSubscriptionConfigService(
      const SubscriptionAppConfig.defaults(),
    );

    await tester.pumpWidget(
      _app(SubscriptionSection(userId: 'user-section', service: service)),
    );
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
    final service = _StaticSubscriptionConfigService(
      const SubscriptionAppConfig.defaults(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionDetailsPage(
          userId: 'user-details',
          service: service,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Découvrez les offres'), findsOneWidget);
    expect(find.text('Particuliers'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Gratuit'), findsOneWidget);
    expect(find.text('iliprestō+'), findsOneWidget);
    expect(find.text('ilipro'), findsNothing);

    await tester.tap(find.text('Pro'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('ilipro'), findsOneWidget);
    expect(find.text('Gratuit'), findsNothing);
    expect(find.text('iliprestō+'), findsNothing);

    await tester.tap(find.text('Particuliers'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Gratuit'), findsOneWidget);
    expect(find.text('iliprestō+'), findsOneWidget);
  });
}
