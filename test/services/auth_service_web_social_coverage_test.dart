import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/auth_service.dart';

class _WebMultiFactorPlatform extends MultiFactorPlatform {
  _WebMultiFactorPlatform(super.auth);
}

class _WebCredentialPlatform extends UserCredentialPlatform {
  _WebCredentialPlatform({
    required super.auth,
    required super.user,
  });
}

class _WebUserPlatform extends UserPlatform {
  _WebUserPlatform(
    FirebaseAuthPlatform authPlatform, {
    required String providerId,
  }) : super(
          authPlatform,
          _WebMultiFactorPlatform(authPlatform),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: 'web-user',
              email: 'web@example.com',
              displayName: 'Utilisateur Web',
              isAnonymous: false,
              isEmailVerified: true,
              creationTimestamp:
                  DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  DateTime(2026, 7, 30).millisecondsSinceEpoch,
            ),
            providerData: <Map<String, dynamic>?>[
              <String, dynamic>{
                'providerId': providerId,
                'uid': 'web-user',
                'email': 'web@example.com',
                'displayName': 'Utilisateur Web',
                'phoneNumber': null,
                'photoURL': null,
                'isAnonymous': false,
                'isEmailVerified': true,
              },
            ],
          ),
        );
}

class _WebAuthPlatform extends FirebaseAuthPlatform {
  _WebAuthPlatform() : super(appInstance: null);

  UserPlatform? user;
  var popupCalls = 0;
  String? popupProviderId;
  String? languageCodeValue;

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
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.value(user);

  @override
  Future<void> setLanguageCode(String? value) async {
    languageCodeValue = value;
  }

  @override
  Future<UserCredentialPlatform> signInWithPopup(
    AuthProvider provider,
  ) async {
    popupCalls += 1;
    popupProviderId = provider.providerId;
    return _WebCredentialPlatform(auth: this, user: user);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _WebAuthPlatform platform;
  late FakeFirebaseFirestore firestore;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _WebAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
  });

  setUp(() {
    firestore = FakeFirebaseFirestore();
    platform
      ..user = null
      ..popupCalls = 0
      ..popupProviderId = null
      ..languageCodeValue = null;
  });

  AuthService webService() {
    return AuthService.forTesting(
      auth: FirebaseAuth.instance,
      firestore: firestore,
      isWeb: true,
    );
  }

  test('Google Web utilise le popup et synchronise le profil', () async {
    platform.user = _WebUserPlatform(platform, providerId: 'google.com');

    final credential = await webService().signInWithGoogle();

    expect(credential.user?.uid, 'web-user');
    expect(platform.languageCodeValue, 'fr');
    expect(platform.popupCalls, 1);
    expect(platform.popupProviderId, 'google.com');

    final profile = await firestore.collection('users').doc('web-user').get();
    expect(profile.data()?['authProvider'], 'google');
    expect(profile.data()?.containsKey('lastLoginAt'), isTrue);
  });

  test('Apple Web utilise le popup et synchronise le profil', () async {
    platform.user = _WebUserPlatform(platform, providerId: 'apple.com');

    final credential = await webService().signInWithApple();

    expect(credential.user?.uid, 'web-user');
    expect(platform.languageCodeValue, 'fr');
    expect(platform.popupCalls, 1);
    expect(platform.popupProviderId, 'apple.com');

    final profile = await firestore.collection('users').doc('web-user').get();
    expect(profile.data()?['authProvider'], 'apple');
    expect(profile.data()?.containsKey('lastLoginAt'), isTrue);
  });
}
