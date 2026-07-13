import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/auth_guard_policy.dart';

void main() {
  const policy = AuthGuardPolicy();

  test('redirige vers le compte sans session', () {
    expect(
      policy.resolve(
        signedIn: false,
        emailVerified: false,
        providerIds: const <String>[],
      ),
      AuthGuardDestination.account,
    );
  });

  test('redirige vers la vérification pour un compte mot de passe', () {
    expect(
      policy.resolve(
        signedIn: true,
        emailVerified: false,
        providerIds: const <String>[' password '],
      ),
      AuthGuardDestination.verifyEmail,
    );
  });

  test('autorise un compte mot de passe vérifié', () {
    expect(
      policy.resolve(
        signedIn: true,
        emailVerified: true,
        providerIds: const <String>['password'],
      ),
      AuthGuardDestination.allow,
    );
  });

  test('autorise les fournisseurs sociaux sans emailVerified', () {
    for (final providers in <List<String>>[
      <String>['google.com'],
      <String>['apple.com'],
      <String>[],
    ]) {
      expect(
        policy.resolve(
          signedIn: true,
          emailVerified: false,
          providerIds: providers,
        ),
        AuthGuardDestination.allow,
      );
    }
  });

  test('un compte multi-fournisseurs garde la contrainte mot de passe', () {
    expect(
      policy.resolve(
        signedIn: true,
        emailVerified: false,
        providerIds: const <String>['google.com', 'PASSWORD'],
      ),
      AuthGuardDestination.verifyEmail,
    );
  });
}
