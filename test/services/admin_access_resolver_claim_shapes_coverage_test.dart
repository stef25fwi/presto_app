import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/admin_access_state.dart';
import 'package:presto_app/services/admin_access_resolver.dart';

class _ClaimsMultiFactorPlatform extends MultiFactorPlatform {
  _ClaimsMultiFactorPlatform(super.auth);
}

class _ClaimsTokenResult extends IdTokenResult {
  _ClaimsTokenResult(Map<String?, Object?> claims)
      : super(
          InternalIdTokenResult(
            token: 'claims-coverage-token',
            claims: claims,
            authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
            signInProvider: 'password',
          ),
        );
}

class _ClaimsUserPlatform extends UserPlatform {
  _ClaimsUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _ClaimsMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'claims-admin',
              email: 'claims-admin@example.com',
              displayName: 'Claims Admin',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp: DateTime(2026, 7, 26).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );
}

class _ClaimsAuthPlatform extends FirebaseAuthPlatform {
  _ClaimsAuthPlatform() : super(appInstance: null);

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

  late _ClaimsAuthPlatform platform;
  late AdminAccessResolver resolver;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _ClaimsAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
  });

  setUp(() {
    platform.user = _ClaimsUserPlatform(platform);
    resolver = AdminAccessResolver(auth: FirebaseAuth.instance);
  });

  AdminAccessState initialState() {
    return AdminAccessState.initial().copyWith(
      isAuthenticated: true,
      uid: 'claims-admin',
      profileLoaded: true,
    );
  }

  test('normalise une chaîne de rôles et conserve leur ordre métier', () async {
    final state = await resolver.syncUserRoleFromClaimsIfNeeded(
      FirebaseAuth.instance.currentUser!,
      _ClaimsTokenResult(<String?, Object?>{
        'roles': ' USER, ADMIN superAdmin ',
      }),
      state: initialState(),
    );

    expect(state.profileHasAdmin, isTrue);
    expect(state.profileRoles, <String>['user', 'admin', 'superadmin']);
    expect(state.profilePrimaryRole, 'user');
    expect(state.lastStage, 'profile-synced-from-token');
  });

  test('reconnaît superadmin comme rôle principal sans liste de rôles', () async {
    final state = await resolver.syncUserRoleFromClaimsIfNeeded(
      FirebaseAuth.instance.currentUser!,
      _ClaimsTokenResult(<String?, Object?>{
        'primaryRole': ' SuperAdmin ',
      }),
      state: initialState(),
    );

    expect(state.profileHasAdmin, isTrue);
    expect(state.profileRoles, <String>['user']);
    expect(state.profilePrimaryRole, 'superadmin');
  });

  test('reconnaît l indicateur historique superAdmin', () async {
    final state = await resolver.syncUserRoleFromClaimsIfNeeded(
      FirebaseAuth.instance.currentUser!,
      _ClaimsTokenResult(<String?, Object?>{
        'superAdmin': true,
      }),
      state: initialState(),
    );

    expect(state.profileHasAdmin, isTrue);
    expect(state.profileRoles, <String>['user']);
    expect(state.profilePrimaryRole, 'user');
  });

  test('ignore une chaîne de rôles ne contenant aucun droit admin', () async {
    final initial = initialState();

    final state = await resolver.syncUserRoleFromClaimsIfNeeded(
      FirebaseAuth.instance.currentUser!,
      _ClaimsTokenResult(<String?, Object?>{
        'roles': ' user moderator ',
        'primaryRole': 'user',
      }),
      state: initial,
    );

    expect(state, same(initial));
    expect(state.profileHasAdmin, isFalse);
  });
}
