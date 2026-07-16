import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_config_service.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';
import 'package:presto_app/features/subscriptions/subscription_widgets.dart';
import 'package:presto_app/pages/admin_videomaker_page.dart';

class _NoUserAuthPlatform extends FirebaseAuthPlatform {
  _NoUserAuthPlatform() : super(appInstance: null);

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(null);
}

class _FakeSubscriptionConfigService extends SubscriptionConfigService {
  _FakeSubscriptionConfigService() : super(firestore: FakeFirebaseFirestore());

  var ensureCalls = 0;

  @override
  Stream<SubscriptionAppConfig> watchConfig({bool ensureExists = false}) {
    return Stream<SubscriptionAppConfig>.value(
      const SubscriptionAppConfig.defaults(),
    );
  }

  @override
  Future<void> ensureDefaultConfigExists({String? updatedBy}) async {
    ensureCalls += 1;
  }
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

Widget _app(
  Widget child, {
  List<NavigatorObserver> observers = const <NavigatorObserver>[],
}) {
  return MaterialApp(
    navigatorObservers: observers,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    ),
  );
}

void _consumeKnownListTileDiagnostic(WidgetTester tester) {
  Object? error;
  while ((error = tester.takeException()) != null) {
    final message = error.toString();
    final isKnownDiagnostic =
        message.contains('ListTile background color or ink splashes') ||
            message.contains('Multiple exceptions');
    if (!isKnownDiagnostic) throw error!;
  }
}

Future<void> _pumpAdminTile(
  WidgetTester tester,
  _FakeSubscriptionConfigService service, {
  List<NavigatorObserver> observers = const <NavigatorObserver>[],
}) async {
  await tester.pumpWidget(
    _app(
      AdminSubscriptionTile(service: service),
      observers: observers,
    ),
  );
  await tester.pump();
  _consumeKnownListTileDiagnostic(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _NoUserAuthPlatform();
  });

  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1200, 2400);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('affiche les contrôles abonnement et la tuile Videomaker',
      (tester) async {
    final service = _FakeSubscriptionConfigService();

    await _pumpAdminTile(tester, service);

    expect(find.text('Abonnements'), findsOneWidget);
    expect(find.text('Videomaker'), findsOneWidget);
    expect(
      find.text('Créer des vidéos VEO depuis un prompt et une image.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.movie_creation_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(service.ensureCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('ouvre la page Videomaker au toucher', (tester) async {
    final service = _FakeSubscriptionConfigService();
    final observer = _RecordingNavigatorObserver();

    await _pumpAdminTile(
      tester,
      service,
      observers: <NavigatorObserver>[observer],
    );

    expect(observer.pushedRoutes, hasLength(1));

    await tester.tap(find.text('Videomaker'));

    expect(observer.pushedRoutes, hasLength(2));
    final route = observer.pushedRoutes.last as MaterialPageRoute<void>;
    final page = route.builder(tester.element(find.text('Videomaker')));
    expect(page, isA<AdminVideoMakerPage>());
  });
}
