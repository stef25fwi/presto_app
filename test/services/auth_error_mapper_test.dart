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
          'Trop de tentatives Firebase ont été détectées. Réessaie dans quelques minutes.',
      'network-request-failed':
          'Problème réseau. Vérifie ta connexion internet puis réessaie.',
      'requires-recent-login':
          'Pour cette action sensible, reconnecte-toi puis réessaie.',
      'credential-already-in-use':
          'Ce moyen de connexion est déjà utilisé par un autre compte.',
      'operation-not-allowed':
          'La vérification par téléphone n’est pas autorisée par la configuration Firebase. Vérifie le provider Téléphone et la règle des régions SMS.',
      'invalid-phone-number':
          'Numéro de téléphone invalide. Vérifie l’indicatif et le format international.',
      'app-not-authorized':
          'Cette application n’est pas autorisée à utiliser Firebase Phone Auth. Vérifie la configuration Android/iOS et les empreintes de l’application.',
      'captcha-check-failed':
          'La vérification anti-abus Firebase a échoué. Relance la vérification et termine le contrôle de sécurité si Firebase le demande.',
      'missing-app-credential':
          'Firebase n’a pas pu valider l’authenticité de l’application pour l’envoi du SMS. Vérifie App Check, Play Integrity/APNs et la configuration Phone Auth.',
      'invalid-app-credential':
          'Firebase n’a pas pu valider l’authenticité de l’application pour l’envoi du SMS. Vérifie App Check, Play Integrity/APNs et la configuration Phone Auth.',
      'missing-client-identifier':
          'Firebase n’a pas pu identifier correctement cet appareil pour la vérification par SMS.',
      'web-context-cancelled':
          'La vérification de sécurité Firebase a été annulée avant l’envoi du SMS.',
      'web-context-already-present':
          'Une vérification Firebase est déjà en cours. Termine-la ou ferme-la avant de recommencer.',
      'phone-verification-timeout':
          'Firebase n’a pas confirmé l’envoi du SMS dans le délai prévu. Réessaie après vérification de la configuration Phone Auth et de la connexion réseau.',
      'phone-verification-start-failed':
          'Firebase Phone Auth n’a pas pu démarrer. Réessaie après vérification de la configuration de l’application.',
      'invalid-verification-code':
          'Code incorrect. Vérifie les chiffres reçus par SMS.',
      'invalid-verification-id': 'La demande a expiré. Renvoie un nouveau code.',
      'session-expired': 'La demande a expiré. Renvoie un nouveau code.',
      'missing-verification-code': 'Saisis le code reçu par SMS.',
      'quota-exceeded':
          'Le quota d’envoi SMS Firebase est atteint. Réessaie plus tard.',
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
        'Erreur d’authentification Firebase : custom-auth-error',
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
