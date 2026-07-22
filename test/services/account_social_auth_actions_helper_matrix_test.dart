import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/account_social_auth_actions.dart';

void main() {
  test('la matrice redirect distingue blocages et annulations', () {
    final expectations = <Object, bool>{
      FirebaseAuthException(code: 'popup-blocked-by-browser'): true,
      FirebaseAuthException(code: 'popup-closed-by-user'): false,
      FirebaseAuthException(code: 'user-cancelled'): false,
      FirebaseAuthException(code: 'internal-error', message: 'plain failure'):
          false,
      StateError('cross-origin restriction'): true,
      StateError('cancelled-popup-request'): false,
      StateError('internal-error without popup signal'): false,
    };

    for (final entry in expectations.entries) {
      expect(
        AccountSocialAuthActions.shouldFallbackToRedirectForTesting(entry.key),
        entry.value,
        reason: entry.key.toString(),
      );
    }
  });

  test('la matrice Facebook traduit chaque famille d erreur', () {
    final expectations = <FirebaseAuthException, String>{
      FirebaseAuthException(code: 'account-exists-with-different-credential'):
          'Un compte existe déjà avec cet email. Utilise ta méthode de connexion habituelle.',
      FirebaseAuthException(code: 'operation-not-allowed'):
          'Connexion Facebook non activée dans Firebase Authentication.',
      FirebaseAuthException(code: 'invalid-credential'):
          'Identifiants Facebook invalides. Réessaie.',
      FirebaseAuthException(code: 'network-request-failed'):
          'Erreur réseau. Vérifie la connexion internet.',
      FirebaseAuthException(code: 'unknown', message: 'détail distant'):
          'détail distant',
      FirebaseAuthException(code: 'unknown'):
          'Erreur de connexion Facebook.',
    };

    for (final entry in expectations.entries) {
      expect(
        AccountSocialAuthActions.facebookErrorMessageForTesting(entry.key),
        entry.value,
        reason: entry.key.code,
      );
    }
  });
}
