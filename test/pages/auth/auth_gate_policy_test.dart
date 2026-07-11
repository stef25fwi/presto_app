// Tests de décision pure du garde d’authentification, sans dépendance Firebase.
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/auth/auth_gate_policy.dart';

void main() {
  const policy = AuthGatePolicy();

  test('redirige un utilisateur déconnecté vers le compte', () {
    expect(
      policy.resolve(
        signedIn: false,
        providerIds: const <String>[],
        emailVerified: false,
      ),
      AuthGateDestination.account,
    );
  });

  test('exige la vérification email pour un compte mot de passe', () {
    expect(
      policy.resolve(
        signedIn: true,
        providerIds: const <String>['password'],
        emailVerified: false,
      ),
      AuthGateDestination.verifyEmail,
    );
  });

  test('autorise un compte mot de passe vérifié', () {
    expect(
      policy.resolve(
        signedIn: true,
        providerIds: const <String>['password'],
        emailVerified: true,
      ),
      AuthGateDestination.verified,
    );
  });

  test('n impose pas la vérification email aux fournisseurs sociaux', () {
    for (final provider in <String>['google.com', 'apple.com']) {
      expect(
        policy.resolve(
          signedIn: true,
          providerIds: <String>[provider],
          emailVerified: false,
        ),
        AuthGateDestination.verified,
        reason: provider,
      );
    }
  });

  test('un compte lié au mot de passe reste soumis à la vérification', () {
    expect(
      policy.resolve(
        signedIn: true,
        providerIds: const <String>['google.com', 'password'],
        emailVerified: false,
      ),
      AuthGateDestination.verifyEmail,
    );
  });

  test('normalise les identifiants de fournisseurs', () {
    expect(
      policy.resolve(
        signedIn: true,
        providerIds: const <String>[' PASSWORD '],
        emailVerified: false,
      ),
      AuthGateDestination.verifyEmail,
    );
  });
}
