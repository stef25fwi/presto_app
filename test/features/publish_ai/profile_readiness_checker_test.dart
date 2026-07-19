import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/publish_ai/profile_readiness.dart';

class _ProfileMultiFactorPlatform extends MultiFactorPlatform {
  _ProfileMultiFactorPlatform(super.auth);
}

class _ProfileUserPlatform extends UserPlatform {
  _ProfileUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _ProfileMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'profile-user-1',
              email: 'profile@ilipresto.fr',
              displayName: 'Stef',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp: DateTime(2026, 7, 1).millisecondsSinceEpoch,
              lastSignInTimestamp: DateTime(2026, 7, 18).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    throw FirebaseException(
      plugin: 'firebase_auth',
      code: 'permission-denied',
      message: 'profile access unavailable in this test',
    );
  }
}

class _ProfileAuthPlatform extends FirebaseAuthPlatform {
  _ProfileAuthPlatform() : super(appInstance: null) {
    user = _ProfileUserPlatform(this);
  }

  late final UserPlatform user;
  bool signedIn = false;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => signedIn ? user : null;

  @override
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.value(currentUser);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(currentUser);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ProfileAuthPlatform platform;
  late FirebaseAuth auth;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _ProfileAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    auth = FirebaseAuth.instance;
  });

  setUp(() {
    platform.signedIn = false;
  });

  test('bloque immédiatement un utilisateur déconnecté', () async {
    final checker = ProfileReadinessChecker(
      auth: auth,
      firestore: FakeFirebaseFirestore(),
    );

    final result = await checker.check();

    expect(result.isReady, isFalse);
    expect(result.gate, ProfileReadinessGate.signedOut);
    expect(result.user, isNull);
    expect(result.describe(), "Connecte-toi pour utiliser la dictée IA.");
  });

  test('convertit un échec de préparation du profil en résultat lisible',
      () async {
    platform.signedIn = true;
    final checker = ProfileReadinessChecker(
      auth: auth,
      firestore: FakeFirebaseFirestore(),
    );

    final result = await checker.check();

    expect(result.isReady, isFalse);
    expect(result.gate, ProfileReadinessGate.readFailed);
    expect(result.user?.uid, 'profile-user-1');
    expect(result.errorDetail, contains('permission-denied'));
    expect(result.describe(), isNotEmpty);
  });
}
