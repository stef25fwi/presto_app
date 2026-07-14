import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/social_auth_policy.dart';

void main() {
  group('SocialAuthPolicy.shouldFallbackToRedirect', () {
    test('accepte les blocages popup explicites', () {
      for (final code in <String>[
        'popup-blocked',
        'popup-blocked-by-browser',
      ]) {
        expect(
          SocialAuthPolicy.shouldFallbackToRedirect(
            FirebaseAuthException(code: code),
          ),
          isTrue,
          reason: code,
        );
      }
    });

    test('refuse les annulations utilisateur', () {
      for (final code in <String>[
        'popup-closed-by-user',
        'cancelled-popup-request',
        'cancelled',
        'user-cancelled',
      ]) {
        expect(
          SocialAuthPolicy.shouldFallbackToRedirect(
            FirebaseAuthException(code: code),
          ),
          isFalse,
          reason: code,
        );
      }
      expect(
        SocialAuthPolicy.shouldFallbackToRedirect(
          StateError('cancelled-popup-request popup blocked'),
        ),
        isFalse,
      );
    });

    test('utilise les signaux navigateur pour internal-error', () {
      expect(
        SocialAuthPolicy.shouldFallbackToRedirect(
          FirebaseAuthException(
            code: 'internal-error',
            message: 'Cross-Origin-Opener-Policy blocked popup',
          ),
        ),
        isTrue,
      );
      expect(
        SocialAuthPolicy.shouldFallbackToRedirect(
          FirebaseAuthException(
            code: 'internal-error',
            message: 'OAuth configuration failed',
          ),
        ),
        isFalse,
      );
      expect(
        SocialAuthPolicy.shouldFallbackToRedirect(
          StateError('internal-error popup blocked'),
        ),
        isTrue,
      );
      expect(
        SocialAuthPolicy.shouldFallbackToRedirect(StateError('other')),
        isFalse,
      );
    });
  });

  group('SocialAuthPolicy.facebookErrorMessage', () {
    test('mappe les erreurs Firebase connues', () {
      const expected = <String, String>{
        'account-exists-with-different-credential': 'compte existe déjà',
        'popup-blocked': 'Pop-up Facebook bloquée',
        'operation-not-allowed': 'non activée',
        'invalid-credential': 'invalides',
        'network-request-failed': 'Erreur réseau',
      };
      for (final entry in expected.entries) {
        expect(
          SocialAuthPolicy.facebookErrorMessage(
            FirebaseAuthException(code: entry.key),
          ),
          contains(entry.value),
          reason: entry.key,
        );
      }
    });

    test('rend les annulations silencieuses', () {
      for (final code in <String>[
        'popup-closed-by-user',
        'cancelled-popup-request',
        'cancelled',
      ]) {
        expect(
          SocialAuthPolicy.facebookErrorMessage(
            FirebaseAuthException(code: code),
          ),
          isEmpty,
        );
      }
    });

    test('utilise le message Firebase ou le fallback générique', () {
      expect(
        SocialAuthPolicy.facebookErrorMessage(
          FirebaseAuthException(code: 'unknown', message: 'detail'),
        ),
        'detail',
      );
      expect(
        SocialAuthPolicy.facebookErrorMessage(
          FirebaseAuthException(code: 'unknown'),
        ),
        'Erreur de connexion Facebook.',
      );
      expect(
        SocialAuthPolicy.facebookErrorMessage(StateError('boom')),
        'Erreur de connexion Facebook. Reessayez.',
      );
    });
  });
}
