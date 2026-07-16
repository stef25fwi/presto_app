import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/auth_service.dart';

class _CompletionMultiFactorPlatform extends MultiFactorPlatform {
  _CompletionMultiFactorPlatform(super.auth);
}

class _CompletionCredentialPlatform extends UserCredentialPlatform {
  _CompletionCredentialPlatform({
    required super.auth,
    required super.user,
  });
}

class _CompletionUserPlatform extends UserPlatform {
  _CompletionUserPlatform(
    this.authPlatform, {
    required String uid,
    required String? email,
    required bool emailVerified,
    required String providerId,
    DateTime? lastSignIn,
  }) : super(
          authPlatform,
          _CompletionMultiFactorPlatform(authPlatform),
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
                  (lastSignIn ?? DateTime.now()).millisecondsSinceEpoch,
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

  final FirebaseAuthPlatform authPlatform;
  var reloadCalls = 0;
  var verificationCalls = 0;
  var reauthenticationCalls = 0;
  var passwordUpdateCalls = 0;
  String? updatedDisplayName;
  String? updatedPassword;
  String? pendingVerifiedEmail;
  ActionCodeSettings? verificationSettings;
  ActionCodeSettings? emailChangeSettings;

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
  Future<void> updateProfile(Map<String, String?> profile) async {
    updatedDisplayName = profile['displayName'];
  }

  @override
  Future<UserCredentialPlatform> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    reauthenticationCalls += 1;
    return _CompletionCredentialPlatform(auth: authPlatform, user: this);
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    passwordUpdateCalls += 1;
    updatedPassword = newPassword;
  }

  @override
  Future<void> verifyBeforeUpdateEmail(
    String newEmail, [
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    pendingVerifiedEmail = newEmail;
    emailChangeSettings = actionCodeSettings;
  }

  @override
  Future<String?> getIdToken(bool forceRefresh) async => 'test-token';
}

class _CompletionAuthPlatform extends FirebaseAuthPlatform {
  _CompletionAuthPlatform() : super(appInstance: null);

  UserPlatform? user;
  String? languageCodeValue;
  String? createdEmail;
  String? createdPassword;
  String? signedInEmail;
  String? signedInPassword;
  String? resetEmail;
  ActionCodeSettings? resetSettings;
  Object? resetError;
  var signOutCalls = 0;
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
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.value(user);

  @override
  Future<void> setLanguageCode(String? value) async {
    languageCodeValue = value;
  }

  @override
  Future<UserCredentialPlatform> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    createdEmail = email;
    createdPassword = password;
    return _CompletionCredentialPlatform(auth: this, user: user);
  }

  @override
  Future<UserCredentialPlatform> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    signedInEmail = email;
    signedInPassword = password;
    return _CompletionCredentialPlatform(auth: this, user: user);
  }

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
    user = null;
  }

  @override
  Future<UserCredentialPlatform> signInWithProvider(
    AuthProvider provider,
  ) async {
    providerCalls += 1;
    providerId = provider.providerId;
    return _CompletionCredentialPlatform(auth: this, user: user);
  }
}

typedef _FunctionCall = ({
  String name,
  Duration timeout,
  Map<String, dynamic> parameters,
  String area,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CompletionAuthPlatform platform;
  late FakeFirebaseFirestore firestore;
  late List<_FunctionCall> functionCalls;
  late int googleSignOutCalls;
  late AuthService service;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    platform = _CompletionAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
  });

  setUp(() {
    platform
      ..user = null
      ..languageCodeValue = null
      ..createdEmail = null
      ..createdPassword = null
      ..signedInEmail = null
      ..signedInPassword = null
      ..resetEmail = null
      ..resetSettings = null
      ..resetError = null
      ..signOutCalls = 0
      ..providerCalls = 0
      ..providerId = null;
    firestore = FakeFirebaseFirestore();
    functionCalls = <_FunctionCall>[];
    googleSignOutCalls = 0;
    service = AuthService.forTesting(
      auth: FirebaseAuth.instance,
      firestore: firestore,
      functionCaller: ({
        required String name,
        required Duration timeout,
        required Map<String, dynamic> parameters,
        required String area,
      }) async {
        functionCalls.add((
          name: name,
          timeout: timeout,
          parameters: Map<String, dynamic>.from(parameters),
          area: area,
        ));
      },
      googleSignOut: () async {
        googleSignOutCalls += 1;
      },
    );
  });

  _CompletionUserPlatform user({
    String uid = 'user-1',
    String? email = 'user@example.com',
    bool verified = false,
    String provider = 'password',
    DateTime? lastSignIn,
  }) {
    return _CompletionUserPlatform(
      platform,
      uid: uid,
      email: email,
      emailVerified: verified,
      providerId: provider,
      lastSignIn: lastSignIn,
    );
  }

  test('inscrit un utilisateur, normalise le profil et envoie la vérification',
      () async {
    final current = user();
    platform.user = current;

    final credential = await service.registerWithEmail(
      email: '  user@example.com  ',
      password: 'secret-123',
      displayName: 'Nom affiché',
      fullName: '  Nom Complet  ',
      firstName: '  Prénom  ',
      lastName: '  Nom  ',
      pseudo: '  pseudo-test  ',
    );

    expect(credential.user?.uid, 'user-1');
    expect(platform.languageCodeValue, 'fr');
    expect(platform.createdEmail, 'user@example.com');
    expect(platform.createdPassword, 'secret-123');
    expect(current.updatedDisplayName, 'pseudo-test');
    expect(current.reloadCalls, 1);
    expect(current.verificationCalls, 1);

    final profile = await firestore.collection('users').doc('user-1').get();
    expect(profile.data()?['displayName'], 'pseudo-test');
    expect(profile.data()?['pseudo'], 'pseudo-test');
    expect(profile.data()?['fullName'], 'Nom Complet');
    expect(profile.data()?['firstName'], 'Prénom');
    expect(profile.data()?['lastName'], 'Nom');
    expect(profile.data()?['authProvider'], 'password');
  });

  test('refuse une inscription dont le credential ne contient aucun user',
      () async {
    platform.user = null;

    await expectLater(
      service.registerWithEmail(
        email: 'user@example.com',
        password: 'secret-123',
        displayName: 'Utilisateur',
      ),
      throwsA(
        isA<FirebaseAuthException>()
            .having((error) => error.code, 'code', 'user-null'),
      ),
    );
  });

  test('connecte par email, recharge le user et journalise le dernier accès',
      () async {
    final current = user();
    platform.user = current;

    final credential = await service.signInWithEmail(
      email: '  user@example.com ',
      password: 'password',
    );

    expect(credential.user?.uid, 'user-1');
    expect(platform.signedInEmail, 'user@example.com');
    expect(platform.signedInPassword, 'password');
    expect(current.reloadCalls, 1);
    final profile = await firestore.collection('users').doc('user-1').get();
    expect(profile.data()?.containsKey('lastLoginAt'), isTrue);
  });

  test('déconnecte Google puis Firebase', () async {
    platform.user = user();

    await service.signOut();

    expect(googleSignOutCalls, 1);
    expect(platform.signOutCalls, 1);
    expect(platform.user, isNull);
  });

  test('envoie un reset neutre et propage les autres erreurs', () async {
    await service.sendPasswordReset(email: '  user@example.com  ');
    expect(platform.languageCodeValue, 'fr');
    expect(platform.resetEmail, 'user@example.com');
    expect(
      platform.resetSettings?.url,
      'https://www.ilipresto.fr/auth/action',
    );

    platform.resetError = FirebaseAuthException(code: 'user-not-found');
    await expectLater(
      service.sendPasswordReset(email: 'missing@example.com'),
      completes,
    );

    platform.resetError = FirebaseAuthException(code: 'too-many-requests');
    await expectLater(
      service.sendPasswordReset(email: 'blocked@example.com'),
      throwsA(
        isA<FirebaseAuthException>()
            .having((error) => error.code, 'code', 'too-many-requests'),
      ),
    );
  });

  test('synchronise immédiatement un email déjà vérifié', () async {
    final current = user(verified: true);
    platform.user = current;

    await service.sendEmailVerificationLink();
    expect(current.reloadCalls, 1);
    expect(current.verificationCalls, 0);
    expect(functionCalls.single.name, 'syncMyEmailVerification');
    expect(functionCalls.single.timeout, const Duration(seconds: 15));
    expect(functionCalls.single.area, 'auth');

    functionCalls.clear();
    expect(await service.checkEmailVerified(), isTrue);
    expect(functionCalls.single.name, 'syncMyEmailVerification');
  });

  test('les opérations protégées refusent une session absente', () async {
    await expectLater(
      service.syncEmailVerifiedToFirestore(),
      throwsA(
        isA<FirebaseAuthException>()
            .having((error) => error.code, 'code', 'not-authenticated'),
      ),
    );
  });

  test('change le mot de passe et écrit les horodatages de sécurité',
      () async {
    final current = user();
    platform.user = current;

    await service.changePassword(
      currentPassword: 'ancien',
      newPassword: 'nouveau-secret',
    );

    expect(current.reauthenticationCalls, 1);
    expect(current.passwordUpdateCalls, 1);
    expect(current.updatedPassword, 'nouveau-secret');
    final profile = await firestore.collection('users').doc('user-1').get();
    expect(profile.data()?.containsKey('passwordChangedAt'), isTrue);
    expect(profile.data()?.containsKey('updatedAt'), isTrue);
  });

  test('demande un changement email après réauthentification', () async {
    final current = user();
    platform.user = current;

    await service.requestEmailChange(
      currentPassword: 'secret',
      newEmail: '  new@example.com  ',
    );

    expect(current.reauthenticationCalls, 1);
    expect(current.pendingVerifiedEmail, 'new@example.com');
    expect(
      current.emailChangeSettings?.url,
      'https://www.ilipresto.fr/auth/action',
    );
    final profile = await firestore.collection('users').doc('user-1').get();
    expect(profile.data()?['pendingEmail'], 'new@example.com');
  });

  test('supprime un compte mot de passe via le backend puis déconnecte',
      () async {
    final current = user();
    platform.user = current;

    await service.deleteCurrentAccount(password: 'secret');

    expect(current.reauthenticationCalls, 1);
    expect(functionCalls.single.name, 'requestAccountDeletion');
    expect(functionCalls.single.timeout, const Duration(seconds: 120));
    expect(functionCalls.single.area, 'account-deletion');
    expect(platform.signOutCalls, 1);
  });

  test('supprime un compte social récemment authentifié sans mot de passe',
      () async {
    final current = user(
      provider: 'google.com',
      lastSignIn: DateTime.now().subtract(const Duration(minutes: 2)),
    );
    platform.user = current;

    await service.deleteCurrentAccount();

    expect(current.reauthenticationCalls, 0);
    expect(functionCalls.single.name, 'requestAccountDeletion');
    expect(platform.signOutCalls, 1);
  });

  test('connexion Apple avec user met à jour le profil social', () async {
    final current = user(provider: 'apple.com');
    platform.user = current;

    final credential = await service.signInWithApple();

    expect(credential.user?.uid, 'user-1');
    expect(platform.providerCalls, 1);
    expect(platform.providerId, 'apple.com');
    final profile = await firestore.collection('users').doc('user-1').get();
    expect(profile.data()?['authProvider'], 'apple');
    expect(profile.data()?.containsKey('lastLoginAt'), isTrue);
  });
}
