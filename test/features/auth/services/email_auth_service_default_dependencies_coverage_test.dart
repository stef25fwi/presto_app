import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/auth/services/auth_service.dart';
import 'package:presto_app/features/auth/services/user_profile_service.dart';

void main() {
  test('signIn utilise le bootstrap profil par défaut injecté', () async {
    final user = _User('signin-default', email: 'user@ilipresto.fr');
    final auth = _Auth(signInUser: user);
    var bootstrapCalls = 0;

    final service = EmailAuthService(
      auth: auth,
      defaultEnsureSignedInUserProfile: ({
        required user,
        required authMethod,
        required isNewUserHint,
      }) async {
        bootstrapCalls += 1;
        expect(user.uid, 'signin-default');
        expect(authMethod, 'email');
        expect(isNewUserHint, isFalse);
      },
    );

    expect(
      await service.signIn(email: ' USER@ILIPRESTO.FR ', password: 'secret'),
      same(user),
    );
    expect(bootstrapCalls, 1);
  });

  test('register construit le service profil par défaut injecté', () async {
    final user = _User('register-default', email: 'pro@ilipresto.fr');
    final auth = _Auth(registerUser: user, currentUserValue: user);
    var factoryCalls = 0;
    var bootstrapCalls = 0;
    Map<String, dynamic>? writtenData;
    var verificationCalls = 0;

    final service = EmailAuthService(
      auth: auth,
      profileServiceFactory: () {
        factoryCalls += 1;
        return AuthUserProfileService(
          timestampFactory: () => 'fixed-time',
          bootstrapUserProfile: ({
            required user,
            required authMethod,
            required isNewUserHint,
            required forceRefresh,
          }) async {
            bootstrapCalls += 1;
          },
          writeUserDocument: ({required uid, required data}) async {
            expect(uid, 'register-default');
            writtenData = data;
          },
        );
      },
      defaultRequestEmailVerification: () async {
        verificationCalls += 1;
      },
    );

    final registered = await service.register(
      displayName: ' Profil test ',
      email: ' PRO@ILIPRESTO.FR ',
      password: 'secret',
    );

    expect(registered, same(user));
    expect(factoryCalls, 1);
    expect(bootstrapCalls, 1);
    expect(writtenData?['displayName'], 'Profil test');
    expect(writtenData?['accountType'], 'Particulier');
    expect(verificationCalls, 1);
  });

  test('reset utilise le backend par défaut puis le fallback Firebase Auth', () async {
    final successfulAuth = _Auth();
    String? backendEmail;
    final backendService = EmailAuthService(
      auth: successfulAuth,
      defaultBackendPasswordReset: (email) async {
        backendEmail = email;
      },
    );

    await backendService.sendPasswordResetEmail(' BACKEND@EXAMPLE.FR ');
    expect(backendEmail, 'backend@example.fr');
    expect(successfulAuth.passwordResetEmail, isNull);

    final fallbackAuth = _Auth();
    final fallbackService = EmailAuthService(
      auth: fallbackAuth,
      defaultBackendPasswordReset: (_) async {
        throw StateError('backend indisponible');
      },
    );

    await fallbackService.sendPasswordResetEmail(' NATIVE@EXAMPLE.FR ');
    expect(fallbackAuth.passwordResetEmail, 'native@example.fr');
  });

  test('sync et vérification utilisent leurs actions par défaut injectées', () async {
    var syncCalls = 0;
    var verificationCalls = 0;
    final service = EmailAuthService(
      hasCurrentUser: () => true,
      defaultSyncEmailVerification: () async {
        syncCalls += 1;
        return true;
      },
      defaultRequestEmailVerification: () async {
        verificationCalls += 1;
      },
    );

    expect(await service.syncCurrentUserEmailVerificationState(), isTrue);
    await service.requestEmailVerificationEmail();
    expect(syncCalls, 1);
    expect(verificationCalls, 1);
  });
}

class _Auth implements FirebaseAuth {
  _Auth({this.signInUser, this.registerUser, this.currentUserValue});

  final User? signInUser;
  final User? registerUser;
  User? currentUserValue;
  String? passwordResetEmail;

  @override
  User? get currentUser => currentUserValue;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _Credential(signInUser);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    currentUserValue = registerUser ?? currentUserValue;
    return _Credential(registerUser);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #sendPasswordResetEmail) {
      passwordResetEmail = invocation.namedArguments[#email] as String?;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _Credential implements UserCredential {
  _Credential(this.user);

  @override
  final User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  _User(this.id, {this.email, this.name});

  final String id;
  @override
  final String? email;
  String? name;
  var reloadCalls = 0;

  @override
  String get uid => id;

  @override
  String? get displayName => name;

  @override
  bool get emailVerified => false;

  @override
  Future<void> updateDisplayName(String? value) async {
    name = value;
  }

  @override
  Future<void> reload() async {
    reloadCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
