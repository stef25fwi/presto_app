import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/publish_ai/profile_readiness.dart';

class _ReadinessMultiFactorPlatform extends MultiFactorPlatform {
  _ReadinessMultiFactorPlatform(super.auth);
}

class _ReadinessUserPlatform extends UserPlatform {
  _ReadinessUserPlatform(FirebaseAuthPlatform auth)
    : super(
        auth,
        _ReadinessMultiFactorPlatform(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: 'publication-profile-user',
            email: 'publication@ilipresto.fr',
            displayName: 'Stef',
            isAnonymous: false,
            isEmailVerified: true,
            creationTimestamp: DateTime(2026, 7, 1).millisecondsSinceEpoch,
            lastSignInTimestamp: DateTime(2026, 7, 23).millisecondsSinceEpoch,
          ),
          providerData: const <Map<String, dynamic>?>[],
        ),
      );

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    throw FirebaseAuthException(
      code: 'network-request-failed',
      message: 'token refresh unavailable in deterministic test',
    );
  }
}

class _ReadinessAuthPlatform extends FirebaseAuthPlatform {
  _ReadinessAuthPlatform() : super(appInstance: null) {
    user = _ReadinessUserPlatform(this);
  }

  late final UserPlatform user;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  UserPlatform? get currentUser => user;

  @override
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.value(currentUser);

  @override
  Stream<UserPlatform?> userChanges() =>
      Stream<UserPlatform?>.value(currentUser);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuth auth;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    FirebaseAuthPlatform.instance = _ReadinessAuthPlatform();
    auth = FirebaseAuth.instance;
  });

  test('lit le profil avec le lecteur Firestore par défaut', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc(auth.currentUser!.uid).set(
      <String, dynamic>{
        'pseudo': 'Stef',
        'city': 'Baie-Mahault',
        'postalCode': '97122',
      },
    );
    var preparationCalls = 0;
    final checker = ProfileReadinessChecker(
      auth: auth,
      firestore: firestore,
      accessPreparer: ({
        required User user,
        required bool forceRefreshAppCheckToken,
      }) async {
        preparationCalls += 1;
        expect(forceRefreshAppCheckToken, isTrue);
        return user;
      },
    );

    final result = await checker.check();

    expect(preparationCalls, 1);
    expect(result.isReady, isTrue);
    expect(result.gate, isNull);
    expect(result.user?.uid, 'publication-profile-user');
  });

  test('utilise le préparateur de profil de production par défaut', () async {
    final checker = ProfileReadinessChecker(
      auth: auth,
      firestore: FakeFirebaseFirestore(),
    );

    final result = await checker.check();

    expect(result.isReady, isFalse);
    expect(result.gate, ProfileReadinessGate.readFailed);
    expect(result.user?.uid, 'publication-profile-user');
    expect(result.errorDetail, contains('network-request-failed'));
  });
}
