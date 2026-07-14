import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/auth/services/auth_service.dart';

void main() {
  test('signIn normalise email et initialise le profil', () async {
    final user = _User('u1', email: 'user@example.com');
    final auth = _Auth(signInUser: user);
    String? method;
    bool? isNew;
    final service = EmailAuthService(
      auth: auth,
      ensureSignedInUserProfile: ({required user, required authMethod, required isNewUserHint}) async {
        method = authMethod;
        isNew = isNewUserHint;
      },
    );
    expect(await service.signIn(email: ' USER@EXAMPLE.COM ', password: 'secret'), same(user));
    expect(auth.signInEmail, 'user@example.com');
    expect(method, 'email');
    expect(isNew, isFalse);
  });

  test('signIn utilise currentUser puis échoue sans user', () async {
    final current = _User('current');
    final fallback = EmailAuthService(
      auth: _Auth(currentUserValue: current),
      ensureSignedInUserProfile: ({required user, required authMethod, required isNewUserHint}) async {},
    );
    expect(await fallback.signIn(email: 'a@b.fr', password: 'x'), same(current));

    final missing = EmailAuthService(auth: _Auth());
    await expectLater(
      missing.signIn(email: 'a@b.fr', password: 'x'),
      throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'user-token-expired')),
    );
  });

  test('register normalise, met à jour le nom et crée un profil pro', () async {
    final created = _User('u2', name: 'Ancien');
    final refreshed = _User('u2', name: 'Nouveau');
    final auth = _Auth(registerUser: created, currentAfterRegister: refreshed);
    String? profileName;
    bool? business;
    var verification = 0;
    final service = EmailAuthService(
      auth: auth,
      ensureEmailUserProfile: ({required user, required displayName, required isBusinessAccount}) async {
        profileName = displayName;
        business = isBusinessAccount;
      },
      requestEmailVerification: () async => verification++,
    );
    expect(
      await service.register(
        displayName: ' Nouveau ',
        email: ' PRO@EXAMPLE.COM ',
        password: 'secret',
        createBusinessProfile: true,
      ),
      same(refreshed),
    );
    expect(auth.registerEmail, 'pro@example.com');
    expect(created.updatedName, 'Nouveau');
    expect(created.reloadCount, 1);
    expect(profileName, 'Nouveau');
    expect(business, isTrue);
    expect(verification, 1);
  });

  test('register évite les mises à jour inutiles et refuse une session vide', () async {
    final sameName = _User('u3', name: 'Identique');
    final service = EmailAuthService(
      auth: _Auth(registerUser: sameName),
      ensureEmailUserProfile: ({required user, required displayName, required isBusinessAccount}) async {},
      requestEmailVerification: () async {},
    );
    await service.register(displayName: 'Identique', email: 'same@example.com', password: 'x');
    expect(sameName.updatedName, isNull);
    expect(sameName.reloadCount, 0);

    final missing = EmailAuthService(auth: _Auth());
    await expectLater(
      missing.register(displayName: 'Test', email: 'test@example.com', password: 'x'),
      throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'user-token-expired')),
    );
  });
}

class _Auth implements FirebaseAuth {
  _Auth({this.signInUser, this.registerUser, this.currentUserValue, this.currentAfterRegister});
  final User? signInUser;
  final User? registerUser;
  User? currentUserValue;
  final User? currentAfterRegister;
  String? signInEmail;
  String? registerEmail;

  @override
  User? get currentUser => currentUserValue;

  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) async {
    signInEmail = email;
    return _Credential(signInUser);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({required String email, required String password}) async {
    registerEmail = email;
    currentUserValue = currentAfterRegister;
    return _Credential(registerUser);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  String? updatedName;
  int reloadCount = 0;
  @override
  String get uid => id;
  @override
  String? get displayName => name;
  @override
  bool get emailVerified => false;
  @override
  Future<void> updateDisplayName(String? value) async {
    updatedName = value;
    name = value;
  }
  @override
  Future<void> reload() async => reloadCount++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
