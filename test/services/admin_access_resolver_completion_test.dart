import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/admin_access_resolver.dart';

class _CompletionMultiFactorPlatform extends MultiFactorPlatform {
  _CompletionMultiFactorPlatform(super.auth);
}

class _CompletionTokenResult extends IdTokenResult {
  _CompletionTokenResult(Map<String?, Object?> claims)
      : super(
          InternalIdTokenResult(
            token: 'completion-token',
            claims: claims,
            authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
            signInProvider: 'password',
          ),
        );
}

class _CompletionUserPlatform extends UserPlatform {
  _CompletionUserPlatform(
    FirebaseAuthPlatform auth, {
    required this.claims,
  }) : super(
          auth,
          _CompletionMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'admin-completion',
              email: 'admin-completion@example.com',
              displayName: 'Admin Completion',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp: DateTime(2026, 7, 20).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );

  Map<String?, Object?> claims;
  Object? reloadError;
  var reloadCalls = 0;
  final List<bool> tokenRequests = <bool>[];

  @override
  Future<void> reload() async {
    reloadCalls += 1;
    final error = reloadError;
    if (error != null) throw error;
  }

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    tokenRequests.add(forceRefresh);
    return forceRefresh ? 'fresh-completion-token' : 'cached-completion-token';
  }

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async {
    return _CompletionTokenResult(claims);
  }
}

class _CompletionAuthPlatform extends FirebaseAuthPlatform {
  _CompletionAuthPlatform() : super(appInstance: null);

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

  @override
  Stream<UserPlatform?> authStateChanges() => Stream<UserPlatform?>.value(user);

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(user);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CompletionAuthPlatform platform;
  late FakeFirebaseFirestore firestore;
  late AdminAccessResolver resolver;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _CompletionAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
  });

  setUp(() {
    platform.user = null;
    firestore = FakeFirebaseFirestore();
    resolver = AdminAccessResolver(
      auth: FirebaseAuth.instance,
      firestore: firestore,
    );
  });

  _CompletionUserPlatform user(Map<String?, Object?> claims) {
    return _CompletionUserPlatform(platform, claims: claims);
  }

  test('finalise sans droit quand profil et serveur ne fournissent aucune preuve',
      () async {
    platform.user = user(<String?, Object?>{
      'roles': <String>['user'],
      'primaryRole': 'user',
    });

    final state = await resolver.resolveAdminAccess();

    expect(state.isAuthenticated, isTrue);
    expect(state.profileLoaded, isTrue);
    expect(state.profileHasAdmin, isFalse);
    expect(state.serverCheckAttempted, isTrue);
    expect(state.serverCheckSucceeded, isFalse);
    expect(state.effectiveIsAdmin, isFalse);
    expect(state.sourceOfTruth, 'none');
    expect(state.lastStage, 'finished');
  });

  test('ignore un échec de reload et conserve la preuve admin du profil',
      () async {
    final current = user(<String?, Object?>{
      'roles': <String>['user'],
    })..reloadError = StateError('reload indisponible');
    platform.user = current;
    await firestore.collection('users').doc('admin-completion').set(
      <String, dynamic>{
        'roles': <String>['admin'],
        'primaryRole': 'admin',
      },
    );

    final state = await resolver.resolveAdminAccess(
      forceRefresh: true,
      returnOnLocalAdminEvidence: true,
    );

    expect(current.reloadCalls, 1);
    expect(current.tokenRequests, <bool>[true]);
    expect(state.profileHasAdmin, isTrue);
    expect(state.sourceOfTruth, 'profile');
    expect(state.effectiveIsAdmin, isTrue);
  });

  test('crée une preuve locale depuis des claims admin sans état initial',
      () async {
    final current = user(const <String?, Object?>{});
    platform.user = current;

    final state = await resolver.syncUserRoleFromClaimsIfNeeded(
      FirebaseAuth.instance.currentUser!,
      _CompletionTokenResult(<String?, Object?>{
        'isAdmin': true,
      }),
    );

    expect(state.profileHasAdmin, isTrue);
    expect(state.profileRoles, <String>['user']);
    expect(state.profilePrimaryRole, 'user');
    expect(state.lastStage, 'profile-synced-from-token');
  });

  test('synchronise le désaccord token profil avant le contrôle serveur',
      () async {
    platform.user = user(<String?, Object?>{
      'roles': <String>['admin'],
      'primaryRole': 'admin',
    });

    final state = await resolver.resolveAdminAccess();

    expect(state.tokenHasAdmin, isTrue);
    expect(state.profileHasAdmin, isTrue);
    expect(state.serverCheckAttempted, isTrue);
    expect(state.effectiveIsAdmin, isTrue);
    expect(state.sourceOfTruth, 'token');
    expect(
      state.debugSteps.any(
        (step) => step.contains('profile flag set from token claims'),
      ),
      isTrue,
    );
  });
}
