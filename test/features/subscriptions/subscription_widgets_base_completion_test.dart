import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_checkout_service.dart';
import 'package:presto_app/features/subscriptions/subscription_config_service.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';
import 'package:presto_app/features/subscriptions/subscription_widgets_base.dart';

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

SubscriptionAppConfig _config({
  bool sectionEnabled = true,
  bool prepared = true,
  bool stripe = false,
  bool freeAccess = false,
}) {
  return SubscriptionAppConfig(
    subscriptionSectionEnabled: sectionEnabled,
    subscriptionsPrepared: prepared,
    stripeEnabled: stripe,
    freeAccessMode: freeAccess,
  );
}

AppUserSubscriptionState _state(SubscriptionPlan plan) {
  return AppUserSubscriptionState(
    plan: plan,
    status: SubscriptionStatus.active,
    subscriptionExpiresAt: null,
    phoneVerified: true,
    proVerified: plan == SubscriptionPlan.ilipro,
  );
}

class _FakeSubscriptionConfigService extends SubscriptionConfigService {
  _FakeSubscriptionConfigService({
    SubscriptionAppConfig? initialConfig,
    this.emitWatchError = false,
  })  : config = initialConfig ?? _config(),
        super(firestore: FakeFirebaseFirestore());

  SubscriptionAppConfig config;
  final bool emitWatchError;
  final StreamController<SubscriptionAppConfig> _updates =
      StreamController<SubscriptionAppConfig>.broadcast(sync: true);

  final List<bool> visibilityUpdates = <bool>[];
  final List<bool> freeAccessUpdates = <bool>[];
  var ensureCalls = 0;
  bool failVisibility = false;
  bool failFreeAccess = false;
  Completer<void>? visibilityCompleter;
  Completer<void>? freeAccessCompleter;

  @override
  Stream<SubscriptionAppConfig> watchConfig({bool ensureExists = false}) {
    if (emitWatchError) {
      return Stream<SubscriptionAppConfig>.error(StateError('config error'));
    }
    return (() async* {
      yield config;
      yield* _updates.stream;
    })();
  }

  @override
  Future<void> ensureDefaultConfigExists({String? updatedBy}) async {
    ensureCalls += 1;
  }

  @override
  Future<void> updateSectionVisibility(
    bool enabled, {
    String? updatedBy,
  }) async {
    visibilityUpdates.add(enabled);
    final completer = visibilityCompleter;
    if (completer != null) await completer.future;
    if (failVisibility) throw StateError('visibility failure');
    config = _config(
      sectionEnabled: enabled,
      prepared: config.subscriptionsPrepared,
      stripe: config.stripeEnabled,
      freeAccess: config.freeAccessMode,
    );
    _updates.add(config);
  }

  @override
  Future<void> updateFreeAccessMode(
    bool enabled, {
    String? updatedBy,
  }) async {
    freeAccessUpdates.add(enabled);
    final completer = freeAccessCompleter;
    if (completer != null) await completer.future;
    if (failFreeAccess) throw StateError('free access failure');
    config = _config(
      sectionEnabled: config.subscriptionSectionEnabled,
      prepared: config.subscriptionsPrepared,
      stripe: config.stripeEnabled,
      freeAccess: enabled,
    );
    _updates.add(config);
  }

  Future<void> close() => _updates.close();
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

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(_app(child));
  await tester.pump();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterExceptionHandler? previousFlutterErrorHandler;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _NoUserAuthPlatform();
  });

  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1200, 3200);
    view.devicePixelRatio = 1;
    SubscriptionCheckoutService.resetForTesting();

    previousFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains(
            'ListTile background color or ink splashes may be invisible.',
          )) {
        return;
      }
      previousFlutterErrorHandler?.call(details);
    };
  });

  tearDown(() {
    FlutterError.onError = previousFlutterErrorHandler;
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
    SubscriptionCheckoutService.resetForTesting();
  });

  testWidgets('la section disparaît quand la configuration est désactivée',
      (tester) async {
    final service = _FakeSubscriptionConfigService(
      initialConfig: _config(sectionEnabled: false),
    );
    addTearDown(service.close);

    await _pump(
      tester,
      SubscriptionSection(userId: 'user-1', service: service),
    );

    expect(find.text('Mon abonnement iliprestō'), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('la section absorbe une erreur de configuration', (tester) async {
    final service = _FakeSubscriptionConfigService(emitWatchError: true);
    addTearDown(service.close);

    await _pump(
      tester,
      SubscriptionSection(userId: 'user-1', service: service),
    );

    expect(find.text('Mon abonnement iliprestō'), findsNothing);
  });

  testWidgets('le bouton détail pousse une page correctement configurée',
      (tester) async {
    final service = _FakeSubscriptionConfigService();
    final observer = _RecordingNavigatorObserver();
    addTearDown(service.close);

    await tester.pumpWidget(
      _app(
        SubscriptionCurrentStatusCard(
          userId: 'user-navigation',
          userState: _state(SubscriptionPlan.free),
          config: _config(),
          service: service,
        ),
        observers: <NavigatorObserver>[observer],
      ),
    );
    await tester.pump();

    expect(observer.pushedRoutes, hasLength(1));
    await tester.tap(find.text('Découvrir les autres offres'));

    expect(observer.pushedRoutes, hasLength(2));
    final route = observer.pushedRoutes.last as MaterialPageRoute<void>;
    final built = route.builder(
      tester.element(find.byType(SubscriptionCurrentStatusCard)),
    );
    expect(built, isA<SubscriptionDetailsPage>());
    final page = built as SubscriptionDetailsPage;
    expect(page.userId, 'user-navigation');
    expect(page.service, same(service));
  });

  testWidgets('ilipresto plus sans Stripe affiche l information de lancement',
      (tester) async {
    await _pump(
      tester,
      SubscriptionPlanTabs(
        config: _config(stripe: false),
        userState: _state(SubscriptionPlan.free),
        audience: OfferAudience.particuliers,
      ),
    );

    await _tapText(tester, 'Choisir iliprestō+');

    expect(
      find.text('Vous serez informé lorsque cette formule sera disponible.'),
      findsOneWidget,
    );
  });

  testWidgets('ilipro sans Stripe affiche l information de lancement',
      (tester) async {
    await _pump(
      tester,
      SubscriptionPlanTabs(
        config: _config(stripe: false),
        userState: _state(SubscriptionPlan.free),
        audience: OfferAudience.pro,
      ),
    );

    await _tapText(tester, 'Choisir ilipro');

    expect(
      find.text('Vous serez informé lorsque cette formule sera disponible.'),
      findsOneWidget,
    );
  });

  testWidgets('retour au plan gratuit déclenche la gestion Stripe',
      (tester) async {
    await _pump(
      tester,
      SubscriptionPlanTabs(
        config: _config(stripe: false),
        userState: _state(SubscriptionPlan.iliprestoPlus),
        showCurrentPlan: true,
        audience: OfferAudience.particuliers,
      ),
    );

    await _tapText(tester, 'Choisir Gratuit');

    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('la tuile admin affiche les états de préparation et Stripe',
      (tester) async {
    final service = _FakeSubscriptionConfigService(
      initialConfig: _config(
        sectionEnabled: true,
        prepared: false,
        stripe: false,
        freeAccess: true,
      ),
    );
    addTearDown(service.close);

    await _pump(tester, AdminSubscriptionTile(service: service));

    expect(find.text('Abonnements'), findsOneWidget);
    expect(find.text('Afficher la section abonnement'), findsOneWidget);
    expect(find.text('Accès gratuit complet'), findsOneWidget);
    expect(find.text('Stripe non activé'), findsOneWidget);
    expect(find.text('Préparation incomplète'), findsOneWidget);
    expect(service.ensureCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('la tuile admin affiche les badges positifs', (tester) async {
    final service = _FakeSubscriptionConfigService(
      initialConfig: _config(prepared: true, stripe: true),
    );
    addTearDown(service.close);

    await _pump(tester, AdminSubscriptionTile(service: service));

    expect(find.text('Stripe activé'), findsOneWidget);
    expect(find.text('Architecture prête'), findsOneWidget);
  });

  testWidgets('la visibilité admin se met à jour avec confirmation',
      (tester) async {
    final service = _FakeSubscriptionConfigService(
      initialConfig: _config(sectionEnabled: false),
    );
    addTearDown(service.close);

    await _pump(tester, AdminSubscriptionTile(service: service));
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Afficher la section abonnement'),
    );
    await tester.pump();

    expect(service.visibilityUpdates, <bool>[true]);
    expect(
      find.text('Visibilité des abonnements mise à jour.'),
      findsOneWidget,
    );
  });

  testWidgets('une erreur de visibilité admin est traduite', (tester) async {
    final service = _FakeSubscriptionConfigService(
      initialConfig: _config(sectionEnabled: false),
    )..failVisibility = true;
    addTearDown(service.close);

    await _pump(tester, AdminSubscriptionTile(service: service));
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Afficher la section abonnement'),
    );
    await tester.pump();

    expect(
      find.text('Impossible de mettre à jour la configuration.'),
      findsOneWidget,
    );
  });

  testWidgets('le mode gratuit admin se met à jour avec confirmation',
      (tester) async {
    final service = _FakeSubscriptionConfigService(
      initialConfig: _config(freeAccess: false),
    );
    addTearDown(service.close);

    await _pump(tester, AdminSubscriptionTile(service: service));
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Accès gratuit complet'),
    );
    await tester.pump();

    expect(service.freeAccessUpdates, <bool>[true]);
    expect(find.text('Mode d’accès abonnement mis à jour.'), findsOneWidget);
  });

  testWidgets('une erreur du mode gratuit admin est traduite', (tester) async {
    final service = _FakeSubscriptionConfigService(
      initialConfig: _config(freeAccess: false),
    )..failFreeAccess = true;
    addTearDown(service.close);

    await _pump(tester, AdminSubscriptionTile(service: service));
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Accès gratuit complet'),
    );
    await tester.pump();

    expect(
      find.text('Impossible de mettre à jour freeAccessMode.'),
      findsOneWidget,
    );
  });

  testWidgets('les deux bascules sont verrouillées pendant une sauvegarde',
      (tester) async {
    final service = _FakeSubscriptionConfigService(
      initialConfig: _config(sectionEnabled: false, freeAccess: false),
    )..visibilityCompleter = Completer<void>();
    addTearDown(service.close);

    await _pump(tester, AdminSubscriptionTile(service: service));
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Afficher la section abonnement'),
    );
    await tester.pump();

    final switches = tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switches.every((tile) => tile.onChanged == null), isTrue);

    service.visibilityCompleter!.complete();
    await tester.pump();
    await tester.pump();

    final restored = tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(restored.every((tile) => tile.onChanged != null), isTrue);
  });
}
