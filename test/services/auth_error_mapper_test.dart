import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/auth_error_mapper.dart';

void main() {
  group('AuthErrorMapper.message', () {
    final expectedMessages = <String, String>{
      'email-already-in-use':
          'Cette adresse email est déjà associée à un compte.',
      'invalid-email': 'Adresse email invalide.',
      'weak-password':
          'Mot de passe trop faible. Utilise au moins 8 caractères avec lettres et chiffres.',
      'wrong-password': 'Email ou mot de passe incorrect.',
      'invalid-credential': 'Email ou mot de passe incorrect.',
      'user-not-found': 'Email ou mot de passe incorrect.',
      'user-disabled': 'Ce compte a été désactivé.',
      'too-many-requests':
          'Trop de tentatives. Réessaie dans quelques minutes.',
      'network-request-failed':
          'Problème réseau. Vérifie ta connexion internet.',
      'requires-recent-login':
          'Pour cette action sensible, reconnecte-toi puis réessaie.',
      'credential-already-in-use':
          'Ce moyen de connexion est déjà utilisé par un autre compte.',
      'operation-not-allowed':
          'Cette méthode de connexion n’est pas encore activée.',
      'invalid-phone-number':
          'Numéro de téléphone invalide. Vérifie le format (ex : +33612345678).',
      'invalid-verification-code':
          'Code incorrect. Vérifie les chiffres reçus par SMS.',
      'invalid-verification-id': 'La demande a expiré. Renvoie un nouveau code.',
      'session-expired': 'La demande a expiré. Renvoie un nouveau code.',
      'missing-verification-code': 'Saisis le code reçu par SMS.',
      'quota-exceeded': 'Trop de SMS envoyés. Réessaie plus tard.',
    };

    for (final entry in expectedMessages.entries) {
      test('mappe ${entry.key}', () {
        final error = FirebaseAuthException(code: entry.key);

        expect(AuthErrorMapper.message(error), entry.value);
      });
    }

    test('conserve le code Firebase inconnu dans le message', () {
      final error = FirebaseAuthException(code: 'custom-auth-error');

      expect(
        AuthErrorMapper.message(error),
        'Erreur d’authentification : custom-auth-error',
      );
    });

    test('retourne un message générique pour une erreur non Firebase', () {
      expect(
        AuthErrorMapper.message(StateError('échec inattendu')),
        'Une erreur est survenue. Réessaie.',
      );
    });
  });
}
