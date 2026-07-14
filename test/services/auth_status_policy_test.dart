import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/auth_status_policy.dart';

void main() {
  const policy = AuthStatusPolicy();

  test('retourne signedOut lorsque la session est absente', () {
    expect(
      policy.resolve(
        signedIn: false,
        emailVerified: false,
        providerIds: const <String>[],
      ),
      AuthStatus.signedOut,
    );
  });

  test('exige la vérification pour un compte mot de passe', () {
    expect(
      policy.resolve(
        signedIn: true,
        emailVerified: false,
        providerIds: const <String>[' password '],
      ),
      AuthStatus.signedInUnverified,
    );
  });

  test('valide un compte mot de passe vérifié', () {
    expect(
      policy.resolve(
        signedIn: true,
        emailVerified: true,
        providerIds: const <String>['password'],
      ),
      AuthStatus.signedInVerified,
    );
  });

  test('valide les comptes sociaux sans imposer emailVerified', () {
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
        AuthStatus.signedInVerified,
      );
    }
  });

  test('un compte multi-fournisseurs reste soumis au mot de passe', () {
    expect(
      policy.resolve(
        signedIn: true,
        emailVerified: false,
        providerIds: const <String>['google.com', 'PASSWORD'],
      ),
      AuthStatus.signedInUnverified,
    );
  });
}
