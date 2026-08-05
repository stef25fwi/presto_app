import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/admin_access_state.dart';
import 'package:presto_app/services/admin_access_resolver.dart';

class _SyncMultiFactorPlatform extends MultiFactorPlatform {
  _SyncMultiFactorPlatform(super.auth);
}

class _SyncTokenResult extends IdTokenResult {
  _SyncTokenResult(Map<String?, Object?> claims)
      : super(
          InternalIdTokenResult(
            token: 'sync-token',
            claims: claims,
            authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
            signInProvider: 'password',
          ),
        );
}

class _SyncUserPlatform extends UserPlatform {
  _SyncUserPlatform(FirebaseAuthPlatform auth)
      : super(
          auth,
          _SyncMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'admin-sync-return',
              email: 'admin-sync-return@example.com',
              displayName: 'Admin Sync Return',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp: DateTime(2026, 7, 20).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );
}

class _SyncAuthPlatform extends FirebaseAuthPlatform {
  _SyncAuthPlatform() : super(appInstance: null);

  late final UserPlatform user = _SyncUserPlatform(this);

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SyncAuthPlatform platform;
  late AdminAccessResolver resolver;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _SyncAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
  });

  setUp(() {
    resolver = AdminAccessResolver(auth: FirebaseAuth.instance);
  });

  test('retourne un état initial quand les claims ne donnent aucun droit admin',
      () async {
    final state = await resolver.syncUserRoleFromClaimsIfNeeded(
      FirebaseAuth.instance.currentUser!,
      _SyncTokenResult(<String?, Object?>{
        'roles': <String>['user'],
        'primaryRole': 'user',
      }),
    );

    expect(state.profileHasAdmin, isFalse);
    expect(state.profileRoles, isEmpty);
    expect(state.profilePrimaryRole, isNull);
    expect(state.lastStage, 'initial');
  });

  test('préserve l’état existant quand le profil contient déjà la preuve admin',
      () async {
    final existing = AdminAccessState.initial().copyWith(
      isAuthenticated: true,
      uid: 'admin-sync-return',
      profileLoaded: true,
      profileHasAdmin: true,
      profileRoles: const <String>['admin'],
      profilePrimaryRole: 'admin',
      lastStage: 'profile-loaded',
    );

    final state = await resolver.syncUserRoleFromClaimsIfNeeded(
      FirebaseAuth.instance.currentUser!,
      _SyncTokenResult(<String?, Object?>{
        'roles': <String>['admin'],
        'primaryRole': 'admin',
      }),
      state: existing,
    );

    expect(identical(state, existing), isTrue);
    expect(state.profileHasAdmin, isTrue);
    expect(state.profileRoles, const <String>['admin']);
    expect(state.lastStage, 'profile-loaded');
  });
}
