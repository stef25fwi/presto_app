import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/journey_entitlements_service.dart';
import 'package:presto_app/features/subscriptions/subscription_config_service.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

class _TestMultiFactorPlatform extends MultiFactorPlatform {
  _TestMultiFactorPlatform(super.auth);
}

class _TestUserPlatform extends UserPlatform {
  _TestUserPlatform(FirebaseAuthPlatform auth, String uid)
      : super(
          auth,
          _TestMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: uid,
              email: '$uid@ilipresto.fr',
              displayName: 'Utilisateur test',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp: DateTime(2026, 7, 1).millisecondsSinceEpoch,
              lastSignInTimestamp: DateTime(2026, 7, 16).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );
}

class _MutableAuthPlatform extends FirebaseAuthPlatform {
  _MutableAuthPlatform() : super(appInstance: null);

  UserPlatform? user;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => user;
}

class _StaticConfigService extends SubscriptionConfigService {
  _StaticConfigService({required this.config, this.failure})
      : super(firestore: FakeFirebaseFirestore());

  final SubscriptionAppConfig config;
  final Object? failure;

  @override
  Future<SubscriptionAppConfig> getConfig() async {
    final error = failure;
    if (error != null) throw error;
    return config;
  }
}

const _freeAccessConfig = SubscriptionAppConfig(
  subscriptionSectionEnabled: true,
  subscriptionsPrepared: true,
  stripeEnabled: false,
  freeAccessMode: true,
);

const _quotaConfig = SubscriptionAppConfig(
  subscriptionSectionEnabled: true,
  subscriptionsPrepared: true,
  stripeEnabled: true,
  freeAccessMode: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MutableAuthPlatform authPlatform;
  late FirebaseAuth auth;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    authPlatform = _MutableAuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
    auth = FirebaseAuth.instance;
  });

  setUp(() {
    authPlatform.user = null;
  });

  test('un visiteur bénéficie du mode accès gratuit complet', () async {
    final service = JourneyEntitlementsService(
      auth: auth,
      firestore: FakeFirebaseFirestore(),
      configService: _StaticConfigService(config: _freeAccessConfig),
    );

    final entitlements = await service.resolveEntitlements();

    expect(entitlements.hasUnlimitedLocalSaves, isTrue);
    expect(entitlements.canExportPdf, isTrue);
    expect(entitlements.hasUnlimitedPdfExports, isTrue);
  });

  test('un utilisateur connecté reçoit les droits de son plan Firestore',
      () async {
    const uid = 'pro-user';
    authPlatform.user = _TestUserPlatform(authPlatform, uid);
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc(uid).set(<String, Object?>{
      'subscriptionPlan': 'ilipro',
      'subscriptionStatus': 'active',
      'phoneVerified': true,
      'proVerified': true,
    });
    final service = JourneyEntitlementsService(
      auth: auth,
      firestore: firestore,
      configService: _StaticConfigService(config: _quotaConfig),
    );

    final entitlements = await service.resolveEntitlements();

    expect(entitlements.maxLocalSavesPerMonth, 10);
    expect(entitlements.canExportPdf, isTrue);
    expect(entitlements.maxPdfExportsPerMonth, 10);
  });

  test('une erreur de configuration revient aux droits du plan Gratuit',
      () async {
    final service = JourneyEntitlementsService(
      auth: auth,
      firestore: FakeFirebaseFirestore(),
      configService: _StaticConfigService(
        config: _quotaConfig,
        failure: StateError('configuration indisponible'),
      ),
    );

    final entitlements = await service.resolveEntitlements();

    expect(entitlements.maxLocalSavesPerMonth, 2);
    expect(entitlements.canExportPdf, isFalse);
    expect(entitlements.maxPdfExportsPerMonth, 0);
  });
}
