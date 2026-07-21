import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/admin_access_resolver.dart';

class _TokenPreviewMultiFactorPlatform extends MultiFactorPlatform {
  _TokenPreviewMultiFactorPlatform(super.auth);
}

class _TokenPreviewResult extends IdTokenResult {
  _TokenPreviewResult(Map<String?, Object?> claims)
      : super(
          InternalIdTokenResult(
            token: 'result-token',
            claims: claims,
            authTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            issuedAtTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
            expirationTimestamp: DateTime(2027, 1, 1).millisecondsSinceEpoch,
            signInProvider: 'password',
          ),
        );
}

class _TokenPreviewUserPlatform extends UserPlatform {
  _TokenPreviewUserPlatform(
    FirebaseAuthPlatform auth, {
    required this.token,
    required this.claims,
  }) : super(
          auth,
          _TokenPreviewMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'admin-token-preview',
              email: 'admin-token-preview@example.com',
              displayName: 'Admin Token Preview',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp: DateTime(2026, 7, 21).millisecondsSinceEpoch,
            ),
            providerData: const <Map<String, dynamic>?>[],
          ),
        );

  final String? token;
  final Map<String?, Object?> claims;

  @override
  Future<String?> getIdToken(bool forceRefresh) async => token;

  @override
  Future<IdTokenResult> getIdTokenResult(bool forceRefresh) async {
    return _TokenPreviewResult(claims);
  }
}

class _TokenPreviewAuthPlatform extends FirebaseAuthPlatform {
  _TokenPreviewAuthPlatform() : super(appInstance: null);

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

  late _TokenPreviewAuthPlatform platform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _TokenPreviewAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
  });

  setUp(() {
    platform.user = null;
  });

  Future<void> expectAdmin({
    required String? token,
    required Map<String?, Object?> claims,
  }) async {
    platform.user = _TokenPreviewUserPlatform(
      platform,
      token: token,
      claims: claims,
    );
    final resolver = AdminAccessResolver(
      auth: FirebaseAuth.instance,
      firestore: FakeFirebaseFirestore(),
    );

    final state = await resolver.resolveAdminAccess(
      returnOnLocalAdminEvidence: true,
    );

    expect(state.tokenLoaded, isTrue);
    expect(state.tokenHasAdmin, isTrue);
    expect(state.effectiveIsAdmin, isTrue);
    expect(state.sourceOfTruth, 'token');
  }

  test('accepte un jeton vide avec le claim admin historique', () async {
    await expectAdmin(
      token: '',
      claims: <String?, Object?>{'admin': true},
    );
  });

  test('accepte un jeton court avec le claim isAdmin', () async {
    await expectAdmin(
      token: 'short-token',
      claims: <String?, Object?>{'isAdmin': true},
    );
  });

  test('accepte un jeton long avec le claim superAdmin', () async {
    await expectAdmin(
      token: '0123456789-admin-token-diagnostic-abcdefghijklmnopqrstuvwxyz',
      claims: <String?, Object?>{'superAdmin': true},
    );
  });
}
