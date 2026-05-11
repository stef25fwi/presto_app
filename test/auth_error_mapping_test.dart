import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/profile_page.dart';

void main() {
  group('friendlyEmailAuthErrorMessage', () {
    test('mappe les nouveaux codes FirebaseAuthException', () {
      expect(
        friendlyEmailAuthErrorMessage('invalid-login-credentials'),
        'E-mail ou mot de passe incorrect.',
      );
      expect(
        friendlyEmailAuthErrorMessage('credential-already-in-use'),
        'Un compte existe deja avec cet e-mail.',
      );
      expect(
        friendlyEmailAuthErrorMessage(
          'account-exists-with-different-credential',
        ),
        'Un compte existe deja avec cet e-mail.',
      );
      expect(
        friendlyEmailAuthErrorMessage('requires-recent-login'),
        'Cette action nécessite une reconnexion récente.',
      );
      expect(
        friendlyEmailAuthErrorMessage('user-token-expired'),
        'Votre session a expiré. Reconnectez-vous.',
      );
      expect(
        friendlyEmailAuthErrorMessage('unverified-email'),
        'Veuillez vérifier votre adresse e-mail avant de continuer.',
      );
      expect(
        friendlyEmailAuthErrorMessage('app-check-token-is-invalid'),
        "Verification de securite echouee. Actualisez l'application et reessayez.",
      );
    });

    test('retourne le fallback si le code est inconnu', () {
      expect(
        friendlyEmailAuthErrorMessage('unknown-code', 'message fallback'),
        'message fallback',
      );
      expect(
        friendlyEmailAuthErrorMessage('unknown-code'),
        'Erreur d\'authentification.',
      );
    });
  });
}
