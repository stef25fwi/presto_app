import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/operating_mode/app_operating_mode.dart';
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

Future<AppOperatingModeService> _freeBetaService() async {
  final service = AppOperatingModeService(
    firestore: FakeFirebaseFirestore(),
  );
  await service.ensureDefaults(updatedBy: 'test-admin');
  return service;
}

Future<void> _pumpAdminTile(
  WidgetTester tester,
  AppOperatingModeService modeService, {
  List<NavigatorObserver> observers = const <NavigatorObserver>[],
}) async {
  await tester.pumpWidget(
    _app(
      AdminSubscriptionTile(operatingModeService: modeService),
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
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1200, 3600);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('affiche le mode bêta, le formulaire juridique et Videomaker',
      (tester) async {
    final modeService = await _freeBetaService();

    await _pumpAdminTile(tester, modeService);

    expect(
      find.text('Mode d’exploitation et identité juridique'),
      findsOneWidget,
    );
    expect(find.text('Activer la version payante'), findsOneWidget);
    expect(find.text('Bêta gratuite'), findsOneWidget);
    expect(find.text('Nom réel de l’éditeur *'), findsOneWidget);
    expect(find.text('Adresse juridiquement utilisable *'), findsOneWidget);
    expect(find.text('Téléphone *'), findsOneWidget);
    expect(find.text('Adresse de contact *'), findsOneWidget);
    expect(find.text('Directeur de publication *'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('save_legal_publisher')),
      findsOneWidget,
    );
    expect(find.text('Videomaker'), findsOneWidget);
    expect(
      find.text('Créer des vidéos VEO depuis un prompt et une image.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.movie_creation_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
  });

  testWidgets('ouvre la page Videomaker au toucher', (tester) async {
    final modeService = await _freeBetaService();
    final observer = _RecordingNavigatorObserver();

    await _pumpAdminTile(
      tester,
      modeService,
      observers: <NavigatorObserver>[observer],
    );

    expect(observer.pushedRoutes, hasLength(1));
    await tester.tap(find.text('Videomaker'));
    expect(observer.pushedRoutes, hasLength(2));

    final route = observer.pushedRoutes.last as MaterialPageRoute<void>;
    final page = route.builder(tester.element(find.text('Videomaker')));
    expect(page, isA<AdminVideoMakerPage>());
  });

  testWidgets('la bêta masque les prix, offres et crédits payants',
      (tester) async {
    final modeService = await _freeBetaService();

    await tester.pumpWidget(
      _app(
        SubscriptionSection(
          userId: 'user-free-beta',
          operatingModeService: modeService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accès bêta gratuit'), findsOneWidget);
    expect(
      find.textContaining('Aucun abonnement, paiement ou commission'),
      findsOneWidget,
    );
    expect(find.text('Mon abonnement iliprestō'), findsNothing);
    expect(find.textContaining('€/mois'), findsNothing);
    expect(find.text('Mes crédits'), findsNothing);
  });
}
