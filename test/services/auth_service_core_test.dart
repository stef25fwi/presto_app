import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/auth_service.dart';

class _AuthServicePlatform extends FirebaseAuthPlatform {
  _AuthServicePlatform() : super(appInstance: null);

  Object? resetError;
  Object? signOutError;
  String? resetEmail;
  ActionCodeSettings? resetSettings;
  var signOutCalls = 0;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) =>
      this;

  @override
  UserPlatform? get currentUser => null;

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(null);

  @override
  Future<void> setLanguageCode(String? languageCode) async {}

  @override
  Future<void> sendPasswordResetEmail(
    String email, [
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    resetEmail = email;
    resetSettings = actionCodeSettings;
    final error = resetError;
    if (error != null) throw error;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    final error = signOutError;
    if (error != null) throw error;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _AuthServicePlatform platform;
  late AuthService service;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _AuthServicePlatform();
    FirebaseAuthPlatform.instance = platform;
    service = AuthService.instance;
  });

  setUp(() {
    platform
      ..resetError = null
      ..signOutError = null
      ..resetEmail = null
      ..resetSettings = null
      ..signOutCalls = 0;
  });

  test('currentUser est null quand aucune session existe', () {
    expect(service.currentUser, isNull);
  });

  test('userChanges émet null sans utilisateur', () async {
    await expectLater(service.userChanges, emits(null));
  });

  test('authStatusChanges émet signedOut sans utilisateur', () async {
    await expectLater(service.authStatusChanges, emits(AuthStatus.signedOut));
  });

  test('sendPasswordReset normalise email et configure le lien', () async {
    await service.sendPasswordReset(email: '  USER@example.com  ');

    expect(platform.resetEmail, 'USER@example.com');
    expect(platform.resetSettings, isNotNull);
    expect(
      platform.resetSettings!.url,
      'https://ilipresto.fr/auth/action',
    );
    expect(platform.resetSettings!.handleCodeInApp, isFalse);
  });

  test('sendPasswordReset masque user-not-found', () async {
    platform.resetError = FirebaseAuthException(code: 'user-not-found');

    await expectLater(
      service.sendPasswordReset(email: 'missing@example.com'),
      completes,
    );
  });

  test('sendPasswordReset retransmet les autres erreurs Firebase', () async {
    platform.resetError = FirebaseAuthException(
      code: 'network-request-failed',
    );

    await expectLater(
      service.sendPasswordReset(email: 'user@example.com'),
      throwsA(
        isA<FirebaseAuthException>().having(
          (error) => error.code,
          'code',
          'network-request-failed',
        ),
      ),
    );
  });

  test('signOut ferme la session Firebase même sans Google initialisé', () async {
    await service.signOut();
    expect(platform.signOutCalls, 1);
  });

  test('les opérations protégées refusent un utilisateur absent', () async {
    Future<void> expectNotAuthenticated(Future<void> Function() action) async {
      await expectLater(
        action(),
        throwsA(
          isA<FirebaseAuthException>().having(
            (error) => error.code,
            'code',
            'not-authenticated',
          ),
        ),
      );
    }

    await expectNotAuthenticated(service.sendEmailVerificationLink);
    await expectNotAuthenticated(service.resendVerificationEmail);
    await expectNotAuthenticated(() async {
      await service.checkEmailVerified();
    });
    await expectNotAuthenticated(service.syncEmailVerifiedToFirestore);
    await expectNotAuthenticated(
      () => service.changePassword(
        currentPassword: 'old',
        newPassword: 'new-password',
      ),
    );
    await expectNotAuthenticated(
      () => service.requestEmailChange(
        currentPassword: 'password',
        newEmail: 'new@example.com',
      ),
    );
    await expectNotAuthenticated(service.deleteCurrentAccount);
  });
}
