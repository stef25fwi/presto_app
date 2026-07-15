import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/auth_service.dart';

class _NullUserCredentialPlatform extends UserCredentialPlatform {
  _NullUserCredentialPlatform({required super.auth}) : super(user: null);
}

class _NullCredentialUserAuthPlatform extends FirebaseAuthPlatform {
  _NullCredentialUserAuthPlatform() : super(appInstance: null);

  String? languageCodeValue;
  String? registeredEmail;
  String? registeredPassword;
  String? signedInEmail;
  String? signedInPassword;

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
  Future<UserCredentialPlatform> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    registeredEmail = email;
    registeredPassword = password;
    return _NullUserCredentialPlatform(auth: this);
  }

  @override
  Future<UserCredentialPlatform> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    signedInEmail = email;
    signedInPassword = password;
    return _NullUserCredentialPlatform(auth: this);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _NullCredentialUserAuthPlatform platform;
  late AuthService service;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _NullCredentialUserAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    service = AuthService.instance;
  });

  setUp(() {
    platform
      ..languageCodeValue = null
      ..registeredEmail = null
      ..registeredPassword = null
      ..signedInEmail = null
      ..signedInPassword = null;
  });

  test('registerWithEmail refuse un credential sans utilisateur', () async {
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
          'user-null',
        ),
      ),
    );

    expect(platform.languageCodeValue, 'fr');
    expect(platform.registeredEmail, 'NEW@example.com');
    expect(platform.registeredPassword, 'Password1');
  });

  test('signInWithEmail retourne le credential quand user est null', () async {
    final credential = await service.signInWithEmail(
      email: '  USER@example.com  ',
      password: 'Password1',
    );

    expect(credential.user, isNull);
    expect(platform.languageCodeValue, 'fr');
    expect(platform.signedInEmail, 'USER@example.com');
    expect(platform.signedInPassword, 'Password1');
  });
}
