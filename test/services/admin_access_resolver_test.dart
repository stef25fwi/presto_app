import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/admin_access_state.dart';
import 'package:presto_app/services/admin_access_resolver.dart';

class _AdminMultiFactorPlatform extends MultiFactorPlatform {
  _AdminMultiFactorPlatform(super.auth);
}

class _AdminTokenResult extends IdTokenResult {
  _AdminTokenResult({
    required Map<String?, Object?> claims,
    String token = 'admin-token-value',
  }) : super(
          InternalIdTokenResult(
            token: token,
            claims: claims,
            authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
            signInProvider: 'password',
          ),
        );
}

class _AdminUserPlatform extends UserPlatform {
  _AdminUserPlatform(
    FirebaseAuthPlatform auth, {
    required String uid,
    required String email,
    Map<String?, Object?> claims = const <String?, Object?>{},
  })  : _claims = claims,
        super(
          auth,
          _AdminMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: uid,
              email: email,
              displayName: 'Admin Test',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp:
                  DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 15).millisecondsSinceEpoch,
            ),
            providerData: <Map<String, dynamic>?>[
              <String, dynamic>{
                'providerId': 'password',
                'uid': uid,
                'email': email,
                'displayName': 'Admin Test',
                'phoneNumber': null,
                'photoURL': null,
                'isAnonymous': false,
                'isEmailVerified': true,
              },
            ],
          ),
        );

  Map<String?, Object?> _claims;
  Object? tokenError;
  var reloadCalls = 0;
  final List<bool> tokenRequests = <bool>[];
  final List<bool> tokenResultRequests = <bool>[];

  set claims(Map<String?, Object?> value) => _claims = value;

  @override
  Future<void> reload() async {
    reloadCalls += 1;
  }

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    tokenRequests.add(forceRefresh);
    final error = tokenError;
    if (error != null) throw error;
    return forceRefresh ? 'forced-admin-token' : 'cached-admin-token';
  }

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async {
    tokenResultRequests.add(forceRefresh);
    final error = tokenError;
    if (error != null) throw error;
    return _AdminTokenResult(claims: _claims);
  }
}

class _AdminAuthPlatform extends FirebaseAuthPlatform {
  _AdminAuthPlatform() : super(appInstance: null);

  UserPlatform? user;
  UserPlatform? restoredUser;
  Object? authStateError;

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
  Stream<UserPlatform?> authStateChanges() {
    final error = authStateError;
    if (error != null) return Stream<UserPlatform?>.error(error);
    return Stream<UserPlatform?>.value(restoredUser ?? user);
  }

  @override
  Stream<UserPlatform?> userChanges() {
    return Stream<UserPlatform?>.value(restoredUser ?? user);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _AdminAuthPlatform platform;
  late FakeFirebaseFirestore firestore;
  late AdminAccessResolver resolver;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _AdminAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
  });

  setUp(() {
    platform
      ..user = null
      ..restoredUser = null
      ..authStateError = null;
    firestore = FakeFirebaseFirestore();
    resolver = AdminAccessResolver(
      auth: FirebaseAuth.instance,
      firestore: firestore,
    );
  });

  _AdminUserPlatform user({
    String uid = 'admin-1',
    String email = 'admin@example.com',
    Map<String?, Object?> claims = const <String?, Object?>{},
  }) {
    return _AdminUserPlatform(
      platform,
      uid: uid,
      email: email,
      claims: claims,
    );
  }

  test('retourne un état final non authentifié après une erreur Auth', () async {
    platform.authStateError = StateError('auth indisponible');

    final state = await resolver.resolveAdminAccess();

    expect(state.isAuthenticated, isFalse);
    expect(state.effectiveIsAdmin, isFalse);
    expect(state.sourceOfTruth, 'none');
    expect(state.lastStage, 'finished');
    expect(state.debugSteps, contains('[AdminResolver] no authenticated user'));
  });

  test('retourne immédiatement les claims admin normalisés', () async {
    final current = user(
      claims: <String?, Object?>{
        'roles': <Object?>[' USER ', 'ADMIN'],
        'primaryRole': ' SuperAdmin ',
      },
    );
    platform.user = current;

    final state = await resolver.resolveAdminAccess(
      returnOnLocalAdminEvidence: true,
    );

    expect(state.isAuthenticated, isTrue);
    expect(state.uid, 'admin-1');
    expect(state.email, 'admin@example.com');
    expect(state.tokenLoaded, isTrue);
    expect(state.tokenHasAdmin, isTrue);
    expect(state.tokenRoles, <String>['user', 'admin']);
    expect(state.tokenPrimaryRole, 'superadmin');
    expect(state.serverCheckAttempted, isFalse);
    expect(state.effectiveIsAdmin, isTrue);
    expect(state.sourceOfTruth, 'token');
    expect(state.lastStage, 'finished');
    expect(current.tokenRequests, <bool>[false]);
    expect(current.tokenResultRequests, <bool>[false]);
  });

  test('restaure un utilisateur depuis authStateChanges', () async {
    final restored = user(
      uid: 'restored-admin',
      email: 'restored@example.com',
      claims: <String?, Object?>{
        'isAdmin': true,
      },
    );
    platform.restoredUser = restored;

    final state = await resolver.resolveAdminAccess(
      returnOnLocalAdminEvidence: true,
    );

    expect(state.isAuthenticated, isTrue);
    expect(state.uid, 'restored-admin');
    expect(state.tokenHasAdmin, isTrue);
    expect(state.sourceOfTruth, 'token');
  });

  test('forceRefresh recharge le compte et demande un token frais', () async {
    final current = user(
      claims: <String?, Object?>{
        'roles': <String>['admin'],
      },
    );
    platform.user = current;

    final state = await resolver.resolveAdminAccess(
      forceRefresh: true,
      returnOnLocalAdminEvidence: true,
    );

    expect(current.reloadCalls, 1);
    expect(current.tokenRequests, <bool>[true]);
    expect(current.tokenResultRequests, <bool>[true]);
    expect(state.effectiveIsAdmin, isTrue);
  });

  test('utilise le profil Firestore quand le token n est pas admin', () async {
    final current = user(
      claims: <String?, Object?>{
        'roles': <String>['user'],
        'primaryRole': 'user',
      },
    );
    platform.user = current;
    await firestore.collection('users').doc('admin-1').set(
      <String, dynamic>{
        'roles': <String>['user', 'admin'],
        'primaryRole': 'admin',
      },
    );

    final state = await resolver.resolveAdminAccess(
      returnOnLocalAdminEvidence: true,
    );

    expect(state.tokenLoaded, isTrue);
    expect(state.tokenHasAdmin, isFalse);
    expect(state.profileLoaded, isTrue);
    expect(state.profileHasAdmin, isTrue);
    expect(state.profileRoles, <String>['user', 'admin']);
    expect(state.profilePrimaryRole, 'admin');
    expect(state.serverCheckAttempted, isFalse);
    expect(state.effectiveIsAdmin, isTrue);
    expect(state.sourceOfTruth, 'profile');
  });

  test('continue vers le profil local quand le chargement token échoue',
      () async {
    final current = user()..tokenError = StateError('token indisponible');
    platform.user = current;
    await firestore.collection('users').doc('admin-1').set(
      <String, dynamic>{
        'admin': true,
        'roles': <String>['admin'],
      },
    );

    final state = await resolver.resolveAdminAccess(
      returnOnLocalAdminEvidence: true,
    );

    expect(state.tokenLoaded, isFalse);
    expect(state.profileLoaded, isTrue);
    expect(state.profileHasAdmin, isTrue);
    expect(state.sourceOfTruth, 'profile');
    expect(state.effectiveIsAdmin, isTrue);
    expect(
      state.debugSteps.any((step) => step.contains('token load failed')),
      isTrue,
    );
  });

  test('synchronisation ignore un token sans rôle admin', () async {
    final current = user();
    platform.user = current;
    final firebaseUser = FirebaseAuth.instance.currentUser!;
    final initial = AdminAccessState.initial().copyWith(
      isAuthenticated: true,
      uid: firebaseUser.uid,
    );

    final state = await resolver.syncUserRoleFromClaimsIfNeeded(
      firebaseUser,
      _AdminTokenResult(
        claims: <String?, Object?>{
          'roles': <String>['user'],
        },
      ),
      state: initial,
    );

    expect(state, same(initial));
    expect(state.profileHasAdmin, isFalse);
  });

  test('synchronisation transforme les claims admin en preuve locale',
      () async {
    final current = user();
    platform.user = current;
    final firebaseUser = FirebaseAuth.instance.currentUser!;
    final initial = AdminAccessState.initial().copyWith(
      isAuthenticated: true,
      uid: firebaseUser.uid,
      profileLoaded: true,
    );

    final state = await resolver.syncUserRoleFromClaimsIfNeeded(
      firebaseUser,
      _AdminTokenResult(
        claims: <String?, Object?>{
          'roles': <String?, Object?>{
            'user': true,
            'admin': true,
            'disabled': false,
          },
          'role': ' Admin ',
        },
      ),
      state: initial,
    );

    expect(state.profileLoaded, isTrue);
    expect(state.profileHasAdmin, isTrue);
    expect(state.profileRoles, <String>['user', 'admin']);
    expect(state.profilePrimaryRole, 'admin');
    expect(state.lastStage, 'profile-synced-from-token');
    expect(state.hasLocalAdminEvidence, isTrue);
  });

  test('synchronisation conserve un profil déjà administrateur', () async {
    final current = user();
    platform.user = current;
    final firebaseUser = FirebaseAuth.instance.currentUser!;
    final existing = AdminAccessState.initial().copyWith(
      isAuthenticated: true,
      uid: firebaseUser.uid,
      profileLoaded: true,
      profileHasAdmin: true,
      profileRoles: <String>['admin'],
    );

    final state = await resolver.syncUserRoleFromClaimsIfNeeded(
      firebaseUser,
      _AdminTokenResult(
        claims: <String?, Object?>{
          'superAdmin': true,
        },
      ),
      state: existing,
    );

    expect(state, same(existing));
  });
}
