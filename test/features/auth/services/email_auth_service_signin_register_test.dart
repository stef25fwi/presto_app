import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/auth/services/auth_service.dart';

void main() {
  group('EmailAuthService.signIn', () {
    test('normalise l email, retourne le user et initialise son profil', () async {
      final user = _FakeUser(uidValue: 'user-1', emailValue: 'user@example.com');
      final auth = _FakeFirebaseAuth(
        signInCredential: _FakeUserCredential(user),
      );
      User? bootstrappedUser;
      String? receivedAuthMethod;
      bool? receivedIsNewUserHint;
      final service = EmailAuthService(
        auth: auth,
        ensureSignedInUserProfile: ({
          required user,
          required authMethod,
          required isNewUserHint,
        }) async {
          bootstrappedUser = user;
          receivedAuthMethod = authMethod;
          receivedIsNewUserHint = isNewUserHint;
        },
      );

      final result = await service.signIn(
        email: '  USER@Example.COM  ',
        password: 'secret-123',
      );

      expect(result, same(user));
      expect(auth.lastSignInEmail, 'user@example.com');
      expect(auth.lastSignInPassword, 'secret-123');
      expect(bootstrappedUser, same(user));
      expect(receivedAuthMethod, 'email');
      expect(receivedIsNewUserHint, isFalse);
    });

    test('utilise auth.currentUser quand le credential ne contient pas de user',
        () async {
      final currentUser = _FakeUser(uidValue: 'fallback-user');
      final auth = _FakeFirebaseAuth(
        signInCredential: _FakeUserCredential(null),
        currentUserValue: currentUser,
      );
      final service = EmailAuthService(
        auth: auth,
        ensureSignedInUserProfile: ({
          required user,
          required authMethod,
          required isNewUserHint,
        }) async {},
      );

      expect(
        await service.signIn(email: 'a@b.fr', password: 'password'),
        same(currentUser),
      );
    });

    test('échoue explicitement si Firebase ne retourne aucun user', () async {
      final auth = _FakeFirebaseAuth(
        signInCredential: _FakeUserCredential(null),
      );
      final service = EmailAuthService(auth: auth);

      await expectLater(
        service.signIn(email: 'a@b.fr', password: 'password'),
        throwsA(
          isA<FirebaseAuthException>().having(
            (error) => error.code,
            'code',
            'user-token-expired',
          ),
        ),
      );
    });
  });

  group('EmailAuthService.register', () {
    test('normalise les champs, met à jour le nom et crée un profil pro',
        () async {
      final createdUser = _FakeUser(
        uidValue: 'created-user',
        emailValue: 'pro@example.com',
        displayNameValue: 'Ancien nom',
      );
      final refreshedUser = _FakeUser(
        uidValue: 'created-user',
        emailValue: 'pro@example.com',
        displayNameValue: 'Nouveau nom',
      );
      final auth = _FakeFirebaseAuth(
        registerCredential: _FakeUserCredential(createdUser),
        currentUserAfterRegister: refreshedUser,
      );
      User? profileUser;
      String? profileName;
      bool? businessAccount;
      var verificationCalls = 0;
      final service = EmailAuthService(
        auth: auth,
        ensureEmailUserProfile: ({
          required user,
          required displayName,
          required isBusinessAccount,
        }) async {
          profileUser = user;
          profileName = displayName;
          businessAccount = isBusinessAccount;
        },
        requestEmailVerification: () async => verificationCalls += 1,
      );

      final result = await service.register(
        displayName: '  Nouveau nom  ',
        email: '  PRO@Example.COM ',
        password: 'password-123',
        createBusinessProfile: true,
      );

      expect(result, same(refreshedUser));
      expect(auth.lastRegisterEmail, 'pro@example.com');
      expect(auth.lastRegisterPassword, 'password-123');
      expect(createdUser.updatedDisplayName, 'Nouveau nom');
      expect(createdUser.reloadCalls, 1);
      expect(profileUser, same(refreshedUser));
      expect(profileName, 'Nouveau nom');
      expect(businessAccount, isTrue);
      expect(verificationCalls, 1);
    });

    test('ne recharge pas le user quand le nom est déjà identique', () async {
      final user = _FakeUser(
        uidValue: 'same-name',
        displayNameValue: 'Nom identique',
      );
      final auth = _FakeFirebaseAuth(
        registerCredential: _FakeUserCredential(user),
      );
      final service = EmailAuthService(
        auth: auth,
        ensureEmailUserProfile: ({
          required user,
          required displayName,
          required isBusinessAccount,
        }) async {},
        requestEmailVerification: () async {},
      );

      await service.register(
        displayName: 'Nom identique',
        email: 'same@example.com',
        password: 'password',
      );

      expect(user.updatedDisplayName, isNull);
      expect(user.reloadCalls, 0);
    });

    test('accepte un nom vide sans mise à jour Firebase', () async {
      final user = _FakeUser(uidValue: 'empty-name');
      final auth = _FakeFirebaseAuth(
        registerCredential: _FakeUserCredential(user),
      );
      String? receivedName;
      final service = EmailAuthService(
        auth: auth,
        ensureEmailUserProfile: ({
          required user,
          required displayName,
          required isBusinessAccount,
        }) async {
          receivedName = displayName;
        },
        requestEmailVerification: () async {},
      );

      await service.register(
        displayName: '   ',
        email: 'empty@example.com',
        password: 'password',
      );

      expect(user.updatedDisplayName, isNull);
      expect(user.reloadCalls, 0);
      expect(receivedName, '');
    });

    test('échoue explicitement si la création ne retourne aucun user',
        () async {
      final auth = _FakeFirebaseAuth(
        registerCredential: _FakeUserCredential(null),
      );
      final service = EmailAuthService(auth: auth);

      await expectLater(
        service.register(
          displayName: 'Test',
          email: 'test@example.com',
          password: 'password',
        ),
        throwsA(
          isA<FirebaseAuthException>().having(
            (error) => error.code,
            'code',
            'user-token-expired',
          ),
        ),
      );
    });
  });
}

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth({
    this.signInCredential,
    this.registerCredential,
    this.currentUserValue,
    this.currentUserAfterRegister,
  });

  final UserCredential? signInCredential;
  final UserCredential? registerCredential;
  User? currentUserValue;
  final User? currentUserAfterRegister;

  String? lastSignInEmail;
  String? lastSignInPassword;
  String? lastRegisterEmail;
  String? lastRegisterPassword;

  @override
  User? get currentUser => currentUserValue;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    lastSignInEmail = email;
    lastSignInPassword = password;
    return signInCredential ?? _FakeUserCredential(null);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    lastRegisterEmail = email;
    lastRegisterPassword = password;
    if (currentUserAfterRegister != null) {
      currentUserValue = currentUserAfterRegister;
    }
    return registerCredential ?? _FakeUserCredential(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserCredential implements UserCredential {
  _FakeUserCredential(this.user);

  @override
  final User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  _FakeUser({
    required this.uidValue,
    this.emailValue,
    this.displayNameValue,
    this.emailVerifiedValue = false,
  });

  final String uidValue;
  final String? emailValue;
  String? displayNameValue;
  final bool emailVerifiedValue;

  String? updatedDisplayName;
  int reloadCalls = 0;

  @override
  String get uid => uidValue;

  @override
  String? get email => emailValue;

  @override
  String? get displayName => displayNameValue;

  @override
  bool get emailVerified => emailVerifiedValue;

  @override
  Future<void> updateDisplayName(String? displayName) async {
    updatedDisplayName = displayName;
    displayNameValue = displayName;
  }

  @override
  Future<void> reload() async {
    reloadCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
