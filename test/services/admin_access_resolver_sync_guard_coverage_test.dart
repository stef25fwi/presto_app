import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/admin_access_state.dart';
import 'package:presto_app/services/admin_access_resolver.dart';

class _SyncGuardMultiFactorPlatform extends MultiFactorPlatform {
  _SyncGuardMultiFactorPlatform(super.auth);
}

class _SyncGuardTokenResult extends IdTokenResult {
  _SyncGuardTokenResult(Map<String?, Object?> claims)
      : super(
          InternalIdTokenResult(
            token: 'sync-guard-token',
            claims: claims,
            authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
            signInProvider: 'password',
          ),
        );
}

class _SyncGuardUserPlatform extends UserPlatform {
  _SyncGuardUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _SyncGuardMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'admin-sync-guard',
              email: 'admin-sync-guard@example.com',
              displayName: 'Admin Sync Guard',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp: DateTime(2026, 7, 26).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );

  @override
  Future<String?> getIdToken(bool forceRefresh) async => 'sync-guard-token';

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async {
    return _SyncGuardTokenResult(const <String?, Object?>{});
  }
}

class _SyncGuardAuthPlatform extends FirebaseAuthPlatform {
  _SyncGuardAuthPlatform() : super(appInstance: null);

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

  late _SyncGuardAuthPlatform platform;
  late AdminAccessResolver resolver;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _SyncGuardAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
  });

  setUp(() {
    platform.user = _SyncGuardUserPlatform(platform);
    resolver = AdminAccessResolver(auth: FirebaseAuth.instance);
  });

  test('returns an initial state when claims do not grant admin access', () async {
    final result = await resolver.syncUserRoleFromClaimsIfNeeded(
      FirebaseAuth.instance.currentUser!,
      _SyncGuardTokenResult(<String?, Object?>{
        'roles': <String>['user'],
        'primaryRole': 'user',
      }),
    );

    expect(result.profileHasAdmin, isFalse);
    expect(result.profileRoles, isEmpty);
    expect(result.lastStage, 'idle');
  });

  test('preserves the supplied state for non-admin claims', () async {
    final initial = AdminAccessState.initial().copyWith(
      profileLoaded: true,
      profileRoles: const <String>['user'],
      profilePrimaryRole: 'user',
      lastStage: 'seed-profile',
    );

    final result = await resolver.syncUserRoleFromClaimsIfNeeded(
      FirebaseAuth.instance.currentUser!,
      _SyncGuardTokenResult(<String?, Object?>{
        'roles': <String>['user'],
        'primaryRole': 'user',
      }),
      state: initial,
    );

    expect(identical(result, initial), isTrue);
    expect(result.lastStage, 'seed-profile');
  });

  test('keeps an existing profile admin proof unchanged', () async {
    final initial = AdminAccessState.initial().copyWith(
      profileLoaded: true,
      profileHasAdmin: true,
      profileRoles: const <String>['admin'],
      profilePrimaryRole: 'admin',
      lastStage: 'profile-loaded',
    );

    final result = await resolver.syncUserRoleFromClaimsIfNeeded(
      FirebaseAuth.instance.currentUser!,
      _SyncGuardTokenResult(<String?, Object?>{
        'roles': <String>['admin'],
        'primaryRole': 'admin',
      }),
      state: initial,
    );

    expect(identical(result, initial), isTrue);
    expect(result.profileHasAdmin, isTrue);
    expect(result.profilePrimaryRole, 'admin');
  });
}
