import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/admin_access_resolver.dart';

class _RebindMultiFactorPlatform extends MultiFactorPlatform {
  _RebindMultiFactorPlatform(super.auth);
}

class _RebindTokenResult extends IdTokenResult {
  _RebindTokenResult()
      : super(
          InternalIdTokenResult(
            token: 'rebind-token',
            claims: <String?, Object?>{
              'roles': <String>['user'],
              'primaryRole': 'user',
            },
            authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
            signInProvider: 'password',
          ),
        );
}

class _RebindUserPlatform extends UserPlatform {
  _RebindUserPlatform(
    FirebaseAuthPlatform auth, {
    required String uid,
    required String email,
    required this.onTokenResult,
  }) : super(
          auth,
          _RebindMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: uid,
              email: email,
              displayName: 'Rebind Test',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp: DateTime(2026, 7, 26).millisecondsSinceEpoch,
            ),
            providerData: <Map<String, dynamic>?>[
              <String, dynamic>{
                'providerId': 'password',
                'uid': uid,
                'email': email,
                'displayName': 'Rebind Test',
                'phoneNumber': null,
                'photoURL': null,
                'isAnonymous': false,
                'isEmailVerified': true,
              },
            ],
          ),
        );

  final void Function() onTokenResult;
  final List<bool> tokenRequests = <bool>[];
  final List<bool> tokenResultRequests = <bool>[];

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    tokenRequests.add(forceRefresh);
    return forceRefresh ? 'rebind-token-fresh' : 'rebind-token-cached';
  }

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async {
    tokenResultRequests.add(forceRefresh);
    onTokenResult();
    return _RebindTokenResult();
  }
}

class _RebindAuthPlatform extends FirebaseAuthPlatform {
  _RebindAuthPlatform() : super(appInstance: null) {
    primary = _RebindUserPlatform(
      this,
      uid: 'admin-primary',
      email: 'primary@example.test',
      onTokenResult: () => exposeReplacement = true,
    );
    replacement = _RebindUserPlatform(
      this,
      uid: 'admin-replacement',
      email: 'replacement@example.test',
      onTokenResult: () {},
    );
  }

  late final _RebindUserPlatform primary;
  late final _RebindUserPlatform replacement;
  bool exposeReplacement = false;

  void reset() {
    exposeReplacement = false;
    primary.tokenRequests.clear();
    primary.tokenResultRequests.clear();
    replacement.tokenRequests.clear();
    replacement.tokenResultRequests.clear();
  }

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser =>
      exposeReplacement ? replacement : primary;

  @override
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.value(currentUser);

  @override
  Stream<UserPlatform?> userChanges() =>
      Stream<UserPlatform?>.value(replacement);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RebindAuthPlatform platform;
  late AdminAccessResolver resolver;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    platform = _RebindAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
  });

  setUp(() {
    platform.reset();
    resolver = AdminAccessResolver(
      auth: FirebaseAuth.instance,
      firestore: FakeFirebaseFirestore(),
    );
  });

  test('signale une session désynchronisée avant le contrôle serveur', () async {
    final state = await resolver.resolveAdminAccess();

    expect(state.isAuthenticated, isTrue);
    expect(state.uid, 'admin-primary');
    expect(state.tokenLoaded, isTrue);
    expect(state.tokenHasAdmin, isFalse);
    expect(state.profileLoaded, isTrue);
    expect(state.serverCheckAttempted, isTrue);
    expect(state.serverCheckSucceeded, isFalse);
    expect(state.serverErrorCode, 'unauthenticated');
    expect(
      state.serverErrorMessage,
      contains('Session client non synchronisée'),
    );
    expect(state.effectiveIsAdmin, isFalse);
    expect(state.sourceOfTruth, 'none');
    expect(state.lastStage, 'finished');
    expect(
      state.debugSteps,
      contains(
        '[AdminResolver] server verification skipped auth binding failed',
      ),
    );
    expect(platform.primary.tokenRequests, <bool>[false]);
    expect(platform.primary.tokenResultRequests, <bool>[false]);
    expect(platform.replacement.tokenRequests, isEmpty);
  });
}
