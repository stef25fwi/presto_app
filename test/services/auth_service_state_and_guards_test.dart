import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/auth_service.dart';

class _AuthMultiFactorPlatform extends MultiFactorPlatform {
  _AuthMultiFactorPlatform(super.auth);
}

class _GuardUserPlatform extends UserPlatform {
  _GuardUserPlatform(
    FirebaseAuthPlatform auth, {
    required String uid,
    required String? email,
    required bool emailVerified,
    required String providerId,
    DateTime? lastSignIn,
  }) : super(
          auth,
          _AuthMultiFactorPlatform(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: uid,
              email: email,
              displayName: 'Utilisateur test',
              isAnonymous: false,
              isEmailVerified: emailVerified,
              creationTimestamp:
                  DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  (lastSignIn ?? DateTime(2026, 1, 1)).millisecondsSinceEpoch,
            ),
            providerData: <Map<String, dynamic>?>[
              <String, dynamic>{
                'providerId': providerId,
                'uid': uid,
                'email': email,
                'displayName': 'Utilisateur test',
                'phoneNumber': null,
                'photoURL': null,
                'isAnonymous': false,
                'isEmailVerified': emailVerified,
              },
            ],
          ),
        );

  var reloadCalls = 0;
  var verificationCalls = 0;
  ActionCodeSettings? verificationSettings;

  @override
  Future<void> reload() async {
    reloadCalls += 1;
  }

  @override
  Future<void> sendEmailVerification(
    ActionCodeSettings? actionCodeSettings,
  ) async {
    verificationCalls += 1;
    verificationSettings = actionCodeSettings;
  }

  @override
  Future<String?> getIdToken(bool forceRefresh) async => 'test-token';
}

class _NullAppleCredentialPlatform extends UserCredentialPlatform {
  _NullAppleCredentialPlatform({required super.auth}) : super(user: null);
}

class _GuardAuthPlatform extends FirebaseAuthPlatform {
  _GuardAuthPlatform() : super(appInstance: null);

  UserPlatform? user;
  String? languageCodeValue;
  var providerCalls = 0;
  String? providerId;

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
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(user);

  @override
  Future<void> setLanguageCode(String? value) async {
    languageCodeValue = value;
  }

  @override
  Future<UserCredentialPlatform> signInWithProvider(
    AuthProvider provider,
  ) async {
    providerCalls += 1;
    providerId = provider.providerId;
    return _NullAppleCredentialPlatform(auth: this);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _GuardAuthPlatform platform;
  late AuthService service;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _GuardAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    service = AuthService.instance;
  });

  setUp(() {
    platform
      ..user = null
      ..languageCodeValue = null
      ..providerCalls = 0
      ..providerId = null;
  });

  _GuardUserPlatform user({
    String? email = 'user@example.com',
    bool verified = false,
    String provider = 'password',
    DateTime? lastSignIn,
  }) {
    return _GuardUserPlatform(
      platform,
      uid: 'user-1',
      email: email,
      emailVerified: verified,
      providerId: provider,
      lastSignIn: lastSignIn,
    );
  }

  test('authStatus distingue mot de passe non vérifié et comptes vérifiés',
      () async {
    platform.user = user();
    await expectLater(
      service.authStatusChanges,
      emits(AuthStatus.signedInUnverified),
    );

    platform.user = user(provider: 'google.com');
    await expectLater(
      service.authStatusChanges,
      emits(AuthStatus.signedInVerified),
    );

    platform.user = user(verified: true);
    await expectLater(
      service.authStatusChanges,
      emits(AuthStatus.signedInVerified),
    );
  });

  test('envoie et renvoie le lien de vérification pour un compte non vérifié',
      () async {
    final current = user();
    platform.user = current;

    await service.sendEmailVerificationLink();
    await service.resendVerificationEmail();

    expect(platform.languageCodeValue, 'fr');
    expect(current.reloadCalls, 2);
    expect(current.verificationCalls, 2);
    expect(
      current.verificationSettings?.url,
      'https://www.ilipresto.fr/auth/action',
    );
    expect(current.verificationSettings?.handleCodeInApp, isFalse);
  });

  test('checkEmailVerified recharge et retourne false', () async {
    final current = user();
    platform.user = current;

    expect(await service.checkEmailVerified(), isFalse);
    expect(current.reloadCalls, 1);
  });

  test('changePassword refuse un compte sans email', () async {
    platform.user = user(email: null);

    await expectLater(
      service.changePassword(
        currentPassword: 'ancien',
        newPassword: 'nouveau',
      ),
      throwsA(
        isA<FirebaseAuthException>().having(
          (error) => error.code,
          'code',
          'missing-email',
        ),
      ),
    );
  });

  test('requestEmailChange refuse un compte sans email', () async {
    platform.user = user(email: '');

    await expectLater(
      service.requestEmailChange(
        currentPassword: 'mot-de-passe',
        newEmail: 'new@example.com',
      ),
      throwsA(
        isA<FirebaseAuthException>().having(
          (error) => error.code,
          'code',
          'missing-email',
        ),
      ),
    );
  });

  test('suppression mot de passe exige email puis mot de passe', () async {
    platform.user = user(email: null);
    await expectLater(
      service.deleteCurrentAccount(password: 'secret'),
      throwsA(
        isA<FirebaseAuthException>().having(
          (error) => error.code,
          'code',
          'missing-email',
        ),
      ),
    );

    platform.user = user();
    await expectLater(
      service.deleteCurrentAccount(),
      throwsA(
        isA<FirebaseAuthException>().having(
          (error) => error.code,
          'code',
          'missing-password',
        ),
      ),
    );
  });

  test('suppression sociale ancienne exige une reconnexion récente', () async {
    platform.user = user(
      provider: 'google.com',
      lastSignIn: DateTime.now().subtract(const Duration(hours: 1)),
    );

    await expectLater(
      service.deleteCurrentAccount(),
      throwsA(
        isA<FirebaseAuthException>().having(
          (error) => error.code,
          'code',
          'requires-recent-login',
        ),
      ),
    );
  });

  test('signInWithApple retourne un credential sans utilisateur', () async {
    final credential = await service.signInWithApple();

    expect(platform.languageCodeValue, 'fr');
    expect(platform.providerCalls, 1);
    expect(platform.providerId, 'apple.com');
    expect(credential.user, isNull);
  });
}
