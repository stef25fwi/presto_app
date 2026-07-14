import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/email_auth_error_mapper.dart';

void main() {
  group('friendlyEmailAuthErrorMessage', () {
    const expectedMessages = <String, String>{
      'invalid-email': 'Adresse e-mail invalide.',
      'missing-email': "L'adresse e-mail est obligatoire.",
      'missing-password': 'Le mot de passe est obligatoire.',
      'user-disabled': 'Ce compte a été désactivé.',
      'user-not-found': 'E-mail ou mot de passe incorrect.',
      'wrong-password': 'E-mail ou mot de passe incorrect.',
      'invalid-credential': 'E-mail ou mot de passe incorrect.',
      'invalid-login-credentials': 'E-mail ou mot de passe incorrect.',
      'email-already-in-use': 'Un compte existe déjà avec cet e-mail.',
      'credential-already-in-use': 'Un compte existe déjà avec cet e-mail.',
      'account-exists-with-different-credential':
          'Un compte existe déjà avec cet e-mail.',
      'weak-password': 'Mot de passe trop faible (minimum 8 caractères).',
      'too-many-requests':
          'Trop de tentatives. Réessayez dans quelques minutes.',
      'network-request-failed':
          'Erreur réseau. Vérifiez votre connexion internet.',
      'operation-not-allowed':
          'Connexion e-mail non activée dans Firebase Authentication.',
      'requires-recent-login':
          'Cette action nécessite une reconnexion récente.',
      'user-token-expired': 'Votre session a expiré. Reconnectez-vous.',
      'unverified-email':
          'Veuillez vérifier votre adresse e-mail avant de continuer.',
      'app-check-token-is-invalid':
          "Vérification de sécurité échouée. Actualisez l'application et réessayez.",
    };

    for (final entry in expectedMessages.entries) {
      test('traduit ${entry.key}', () {
        expect(friendlyEmailAuthErrorMessage(entry.key), entry.value);
      });
    }

    test('normalise les espaces autour du code', () {
      expect(
        friendlyEmailAuthErrorMessage('  invalid-email  '),
        'Adresse e-mail invalide.',
      );
    });

    test('utilise le fallback nettoyé pour un code inconnu', () {
      expect(
        friendlyEmailAuthErrorMessage('unknown', '  Message fournisseur  '),
        'Message fournisseur',
      );
    });

    test('utilise le message générique sans fallback exploitable', () {
      expect(
        friendlyEmailAuthErrorMessage('unknown'),
        "Erreur d'authentification.",
      );
      expect(
        friendlyEmailAuthErrorMessage('unknown', '   '),
        "Erreur d'authentification.",
      );
    });
  });

  group('mapEmailAuthError', () {
    test('traduit une FirebaseAuthException connue', () {
      final error = FirebaseAuthException(
        code: 'wrong-password',
        message: 'Provider message',
      );

      expect(mapEmailAuthError(error), 'E-mail ou mot de passe incorrect.');
    });

    test('utilise le message Firebase pour un code inconnu', () {
      final error = FirebaseAuthException(
        code: 'custom-provider-error',
        message: '  Erreur du fournisseur  ',
      );

      expect(mapEmailAuthError(error), 'Erreur du fournisseur');
    });

    test('nettoie le préfixe Exception pour une erreur standard', () {
      expect(mapEmailAuthError(Exception('Échec local')), 'Échec local');
    });

    test('retourne le message générique pour une erreur vide', () {
      expect(mapEmailAuthError(_EmptyError()), "Erreur d'authentification.");
    });

    test('conserve la représentation des autres objets', () {
      expect(mapEmailAuthError(42), '42');
    });
  });

  group('messages de succès', () {
    test('normalise l’adresse de réinitialisation', () {
      expect(
        mapPasswordResetSuccessMessage('  USER@EXAMPLE.COM  '),
        'E-mail de réinitialisation envoyé à user@example.com.',
      );
    });

    test('reste non révélateur lorsque l’adresse est vide', () {
      expect(
        mapPasswordResetSuccessMessage('   '),
        'Si un compte existe, un e-mail de réinitialisation a été envoyé.',
      );
    });

    test('retourne le message de vérification', () {
      expect(
        mapEmailVerificationSuccessMessage(),
        'E-mail de vérification envoyé. Vérifie ta boîte mail.',
      );
    });
  });
}

class _EmptyError {
  @override
  String toString() => '   ';
}
