import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/operating_mode/app_operating_mode.dart';
import 'package:presto_app/features/subscriptions/subscription_config_service.dart';
import 'package:presto_app/features/subscriptions/subscription_widgets.dart';

class _NoSubscriptionUserAuthPlatform extends FirebaseAuthPlatform {
  _NoSubscriptionUserAuthPlatform() : super(appInstance: null);

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

class _ThrowingModeService extends AppOperatingModeService {
  _ThrowingModeService() : super(firestore: FakeFirebaseFirestore());

  @override
  Stream<AppOperatingModeState> watchState({bool ensureExists = false}) {
    throw StateError('mode stream unavailable');
  }
}

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _NoSubscriptionUserAuthPlatform();
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

  testWidgets('le service de mode par défaut conserve le repli bêta',
      (tester) async {
    await tester.pumpWidget(
      _host(const SubscriptionSection(userId: 'default-mode-user')),
    );
    await tester.pump();

    expect(find.text('Accès bêta gratuit'), findsOneWidget);
  });

  testWidgets('une erreur synchrone du flux de mode replie vers la bêta',
      (tester) async {
    await tester.pumpWidget(
      _host(
        SubscriptionSection(
          userId: 'throwing-mode-user',
          operatingModeService: _ThrowingModeService(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Accès bêta gratuit'), findsOneWidget);
  });

  testWidgets('le mode commercial accepté affiche offres et crédits',
      (tester) async {
    const userId = 'commercial-subscriber';
    final firestore = FakeFirebaseFirestore();
    final effectiveDate = DateTime.utc(2026, 7, 23);
    await firestore.collection('app_config').doc('legal').set(
      <String, dynamic>{
        'operatingMode': 'commercial',
        'legalVersion': 'commercial-v1',
        'cguVersion': 'cgu-commercial-v1',
        'privacyVersion': 'privacy-commercial-v1',
        'effectiveDate': Timestamp.fromDate(effectiveDate),
        'requiresReacceptance': true,
      },
    );
    await firestore.collection('app_config').doc('subscriptions').set(
      <String, dynamic>{
        'operatingMode': 'commercial',
        'subscriptionSectionEnabled': true,
        'subscriptionsPrepared': true,
        'stripeEnabled': true,
        'freeAccessMode': false,
      },
    );
    await firestore.collection('users').doc(userId).set(
      <String, dynamic>{
        'legalAcceptance': <String, dynamic>{
          'operatingMode': 'commercial',
          'legalVersion': 'commercial-v1',
          'cguVersion': 'cgu-commercial-v1',
          'privacyVersion': 'privacy-commercial-v1',
        },
      },
    );

    await tester.pumpWidget(
      _host(
        SubscriptionSection(
          userId: userId,
          operatingModeService: AppOperatingModeService(
            firestore: firestore,
          ),
          firestore: firestore,
          service: SubscriptionConfigService(firestore: firestore),
        ),
      ),
    );
    for (var frame = 0; frame < 12; frame += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Accès bêta gratuit'), findsNothing);
    expect(find.byType(SubscriptionCreditsCard), findsOneWidget);
    expect(find.text('Nouvelles conditions à accepter'), findsNothing);
  });
}
