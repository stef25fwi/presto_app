// The Google platform interface is used only to execute the real app-facing
// GoogleSignIn singleton deterministically in this coverage test.
// ignore_for_file: depend_on_referenced_packages

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:presto_app/services/auth_service.dart';

class _GooglePlatform extends GoogleSignInPlatform {
  var authenticateCalls = 0;
  InitParameters? initParameters;

  @override
  Future<void> init(InitParameters params) async {
    initParameters = params;
  }

  @override
  Future<AuthenticationResults?> attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async =>
      null;

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    authenticateCalls += 1;
    return const AuthenticationResults(
      user: GoogleSignInUserData(
        email: 'google@ilipresto.fr',
        id: 'google-user-1',
        displayName: 'Google User',
        photoUrl: null,
      ),
      authenticationTokens: AuthenticationTokenData(
        idToken: 'google-id-token',
      ),
    );
  }

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async =>
      null;

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async =>
      null;

  @override
  Future<void> signOut(SignOutParams params) async {}

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}

class _MultiFactor extends MultiFactorPlatform {
  _MultiFactor(super.auth);
}

class _UserPlatform extends UserPlatform {
  _UserPlatform(
    FirebaseAuthPlatform auth, {
    required String uid,
    required String email,
    required String providerId,
    required bool emailVerified,
    DateTime? lastSignIn,
  }) : super(
          auth,
          _MultiFactor(auth),
          InternalUserDetails(
            userInfo: InternalUserInfo(
              uid: uid,
              email: email,
              displayName: 'Nom initial',
              isAnonymous: false,
              isEmailVerified: emailVerified,
              creationTimestamp: DateTime(2026, 1, 1).millisecondsSinceEpoch,
              lastSignInTimestamp:
                  (lastSignIn ?? DateTime.now()).millisecondsSinceEpoch,
            ),
            providerData: <Map<String, dynamic>?>[
              <String, dynamic>{
                'providerId': providerId,
                'uid': uid,
                'email': email,
                'displayName': 'Nom initial',
                'phoneNumber': null,
                'photoURL': null,
                'isAnonymous': false,
                'isEmailVerified': emailVerified,
              },
            ],
          ),
        );

  String? updatedDisplayName;
  var reloadCalls = 0;
  var verificationCalls = 0;

  @override
  Future<void> updateProfile(Map<String, String?> profile) async {
    updatedDisplayName = profile['displayName'];
  }

  @override
  Future<void> reload() async {
    reloadCalls += 1;
  }

  @override
  Future<void> sendEmailVerification(
    ActionCodeSettings? actionCodeSettings,
  ) async {
    verificationCalls += 1;
  }
}

class _CredentialPlatform extends UserCredentialPlatform {
  _CredentialPlatform({required super.auth, required super.user});
}

class _AuthPlatform extends FirebaseAuthPlatform {
  _AuthPlatform() : super(appInstance: null);

  UserPlatform? user;
  String? languageCodeValue;
  String? credentialProviderId;
  String? createdEmail;
  String? createdPassword;
  Object? signOutError;
  var credentialCalls = 0;
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
  UserPlatform? get currentUser => user;

  @override
  Stream<UserPlatform?> userChanges() => Stream<UserPlatform?>.value(user);

  @override
  Future<void> setLanguageCode(String? value) async {
    languageCodeValue = value;
  }

  @override
  Future<UserCredentialPlatform> signInWithCredential(
    AuthCredential credential,
  ) async {
    credentialCalls += 1;
    credentialProviderId = credential.providerId;
    return _CredentialPlatform(auth: this, user: user);
  }

  @override
  Future<UserCredentialPlatform> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    createdEmail = email;
    createdPassword = password;
    return _CredentialPlatform(auth: this, user: user);
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    final error = signOutError;
    if (error != null) throw error;
    user = null;
  }
}

typedef _FunctionCall = ({String name, String area});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _GooglePlatform googlePlatform;
  late _AuthPlatform authPlatform;
  late FirebaseAuth auth;
  late FakeFirebaseFirestore firestore;
  late List<_FunctionCall> functionCalls;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();

    googlePlatform = _GooglePlatform();
    GoogleSignInPlatform.instance = googlePlatform;
    await GoogleSignIn.instance.initialize();

    authPlatform = _AuthPlatform();
    FirebaseAuthPlatform.instance = authPlatform;
    auth = FirebaseAuth.instance;
  });

  setUp(() {
    googlePlatform.authenticateCalls = 0;
    authPlatform
      ..user = null
      ..languageCodeValue = null
      ..credentialProviderId = null
      ..createdEmail = null
      ..createdPassword = null
      ..signOutError = null
      ..credentialCalls = 0
      ..signOutCalls = 0;
    firestore = FakeFirebaseFirestore();
    functionCalls = <_FunctionCall>[];
  });

  AuthService service() {
    return AuthService.forTesting(
      auth: auth,
      firestore: firestore,
      functionCaller: ({
        required String name,
        required Duration timeout,
        required Map<String, dynamic> parameters,
        required String area,
      }) async {
        functionCalls.add((name: name, area: area));
      },
      googleSignOut: () async {},
    );
  }

  _UserPlatform socialUser() {
    return _UserPlatform(
      authPlatform,
      uid: 'google-user-1',
      email: 'google@ilipresto.fr',
      providerId: 'google.com',
      emailVerified: true,
      lastSignIn: DateTime.now().subtract(const Duration(minutes: 2)),
    );
  }

  test('exécute le flux Google mobile par défaut et écrit le profil', () async {
    authPlatform.user = socialUser();

    final credential = await service().signInWithGoogle();

    expect(googlePlatform.authenticateCalls, 1);
    expect(authPlatform.languageCodeValue, 'fr');
    expect(authPlatform.credentialCalls, 1);
    expect(authPlatform.credentialProviderId, 'google.com');
    expect(credential.user?.uid, 'google-user-1');

    final profile =
        await firestore.collection('users').doc('google-user-1').get();
    expect(profile.data()?['authProvider'], 'google');
    expect(profile.data()?.containsKey('lastLoginAt'), isTrue);
  });

  test('utilise displayName comme pseudo lorsque pseudo est absent', () async {
    final current = _UserPlatform(
      authPlatform,
      uid: 'password-user-1',
      email: 'password@ilipresto.fr',
      providerId: 'password',
      emailVerified: false,
    );
    authPlatform.user = current;

    await service().registerWithEmail(
      email: '  password@ilipresto.fr ',
      password: 'secret-123',
      displayName: '  Alias public  ',
    );

    expect(current.updatedDisplayName, 'Alias public');
    expect(current.reloadCalls, 1);
    expect(current.verificationCalls, 1);
    final profile =
        await firestore.collection('users').doc('password-user-1').get();
    expect(profile.data()?['pseudo'], 'Alias public');
    expect(profile.data()?['displayName'], 'Alias public');
  });

  test('termine la suppression si la session locale est déjà invalide',
      () async {
    authPlatform
      ..user = socialUser()
      ..signOutError = FirebaseAuthException(
        code: 'user-token-expired',
        message: 'session supprimée par le backend',
      );

    await service().deleteCurrentAccount();

    expect(functionCalls.single.name, 'requestAccountDeletion');
    expect(functionCalls.single.area, 'account-deletion');
    expect(authPlatform.signOutCalls, 1);
  });
}
