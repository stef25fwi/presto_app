import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/auth_service.dart';

class _EmailFailureAuthPlatform extends FirebaseAuthPlatform {
  _EmailFailureAuthPlatform() : super(appInstance: null);

  String? languageCodeValue;
  String? registeredEmail;
  String? registeredPassword;
  String? signedInEmail;
  String? signedInPassword;
  Object registerError = FirebaseAuthException(code: 'email-already-in-use');
  Object signInError = FirebaseAuthException(code: 'invalid-credential');

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
  Future<void> setLanguageCode(String? languageCode) async {
    languageCodeValue = languageCode;
  }

  @override
  Future<dynamic> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    registeredEmail = email;
    registeredPassword = password;
    throw registerError;
  }

  @override
  Future<dynamic> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    signedInEmail = email;
    signedInPassword = password;
    throw signInError;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _EmailFailureAuthPlatform platform;
  late AuthService service;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _EmailFailureAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    service = AuthService.instance;
  });

  setUp(() {
    platform
      ..languageCodeValue = null
      ..registeredEmail = null
      ..registeredPassword = null
      ..signedInEmail = null
      ..signedInPassword = null
      ..registerError = FirebaseAuthException(code: 'email-already-in-use')
      ..signInError = FirebaseAuthException(code: 'invalid-credential');
  });

  test('registerWithEmail normalise l email et propage l erreur Firebase', () async {
    await expectLater(
      service.registerWithEmail(
        email: '  NEW@example.com  ',
        password: 'Password1',
        displayName: 'Nouveau',
      ),
      throwsA(
        isA<FirebaseAuthException>().having(
          (error) => error.code,
          'code',
          'email-already-in-use',
        ),
      ),
    );

    expect(platform.languageCodeValue, 'fr');
    expect(platform.registeredEmail, 'NEW@example.com');
    expect(platform.registeredPassword, 'Password1');
  });

  test('registerWithEmail propage aussi une erreur inattendue', () async {
    platform.registerError = StateError('register unavailable');

    await expectLater(
      service.registerWithEmail(
        email: 'user@example.com',
        password: 'Password1',
        displayName: 'Utilisateur',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('signInWithEmail normalise l email et propage l erreur Firebase', () async {
    await expectLater(
      service.signInWithEmail(
        email: '  USER@example.com  ',
        password: 'Password1',
      ),
      throwsA(
        isA<FirebaseAuthException>().having(
          (error) => error.code,
          'code',
          'invalid-credential',
        ),
      ),
    );

    expect(platform.languageCodeValue, 'fr');
    expect(platform.signedInEmail, 'USER@example.com');
    expect(platform.signedInPassword, 'Password1');
  });

  test('signInWithEmail propage une erreur inattendue', () async {
    platform.signInError = StateError('sign-in unavailable');

    await expectLater(
      service.signInWithEmail(
        email: 'user@example.com',
        password: 'Password1',
      ),
      throwsA(isA<StateError>()),
    );
  });
}
