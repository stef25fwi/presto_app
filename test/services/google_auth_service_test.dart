import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/config/app_check_state.dart';
import 'package:presto_app/services/google_auth_service.dart';

void main() {
  final service = GoogleAuthService();

  tearDown(() {
    appCheckActivationAttempted = false;
    appCheckActivationSucceeded = false;
  });

  group('GoogleAuthService.getErrorMessage', () {
    test('mappe les erreurs Firebase connues', () {
      const expectedFragments = <String, String>{
        'auth-error': "Erreur d'authentification",
        'invalid-oauth-client': 'configuration OAuth',
        'idp-error': "fournisseur d'identité",
        'unauthorized-domain': 'Domaine non autorisé',
        'operation-not-allowed': 'Google Sign-In désactivé',
        'popup-blocked': 'Pop-up bloquée',
        'network-request-failed': 'Erreur réseau',
        'account-exists-with-different-credential': 'autre méthode',
        'invalid-credential': 'Identifiants invalides',
        'user-disabled': 'compte a été désactivé',
        'user-not-found': 'Aucun compte trouvé',
        'wrong-password': 'Mot de passe incorrect',
        'invalid-email': 'Email invalide',
      };

      for (final entry in expectedFragments.entries) {
        final message = service.getErrorMessage(
          FirebaseAuthException(code: entry.key, message: 'detail'),
        );
        expect(message, contains(entry.value), reason: entry.key);
      }
    });

    test('rend les annulations Firebase silencieuses', () {
      for (final code in <String>[
        'popup-closed-by-user',
        'cancelled-popup-request',
        'cancelled',
      ]) {
        expect(
          service.getErrorMessage(FirebaseAuthException(code: code)),
          isEmpty,
          reason: code,
        );
      }
    });

    test('distingue internal-error App Check et popup', () {
      expect(
        service.getErrorMessage(
          FirebaseAuthException(
            code: 'internal-error',
            message: 'INVALID_APP_CREDENTIAL',
          ),
        ),
        contains('Vérification de sécurité'),
      );

      appCheckActivationAttempted = false;
      appCheckActivationSucceeded = false;
      expect(
        service.getErrorMessage(
          FirebaseAuthException(
            code: 'internal-error',
            message: 'OAuth popup failure',
          ),
        ),
        contains("fenêtre Google n'a pas pu s'ouvrir"),
      );
    });

    test('utilise le fallback Firebase et le fallback générique', () {
      expect(
        service.getErrorMessage(
          FirebaseAuthException(code: 'unknown-code', message: 'detail'),
        ),
        contains('detail'),
      );
      expect(service.getErrorMessage(StateError('boom')), contains('inattendue'));
    });

    test('mappe les erreurs PlatformException', () {
      const expectedFragments = <String, String>{
        'network_error': 'Erreur réseau',
        'sign_in_failed': 'Connexion échouée',
        'google_sign_in_failed': 'Erreur Google Sign-In',
        'missing_google_play_services': 'Google Play Services',
      };
      for (final entry in expectedFragments.entries) {
        expect(
          service.getErrorMessage(
            PlatformException(code: entry.key, message: 'detail'),
          ),
          contains(entry.value),
          reason: entry.key,
        );
      }
      for (final code in <String>['sign_in_canceled', 'sign_in_cancelled']) {
        expect(
          service.getErrorMessage(PlatformException(code: code)),
          isEmpty,
        );
      }
      expect(
        service.getErrorMessage(
          PlatformException(
            code: 'sign_in_failed',
            message: 'package certificate hash missing',
          ),
        ),
        contains('interrompue'),
      );
      expect(
        service.getErrorMessage(
          PlatformException(code: 'other', message: 'platform detail'),
        ),
        contains('platform detail'),
      );
    });
  });

  group('retry et fallback redirect', () {
    test('retry uniquement les erreurs temporaires', () {
      for (final code in <String>[
        'network-request-failed',
        'internal-error',
        'idp-error',
      ]) {
        expect(
          service.shouldRetry(FirebaseAuthException(code: code)),
          isTrue,
          reason: code,
        );
      }
      expect(
        service.shouldRetry(FirebaseAuthException(code: 'invalid-email')),
        isFalse,
      );
      expect(
        service.shouldRetry(PlatformException(code: 'network_error')),
        isTrue,
      );
      expect(
        service.shouldRetry(PlatformException(code: 'sign_in_failed')),
        isFalse,
      );
      expect(service.shouldRetry(StateError('boom')), isFalse);
    });

    test('fallback redirect uniquement pour un vrai blocage navigateur', () {
      expect(
        service.shouldFallbackToRedirect(
          FirebaseAuthException(code: 'popup-blocked'),
        ),
        isTrue,
      );
      expect(
        service.shouldFallbackToRedirect(
          FirebaseAuthException(code: 'popup-blocked-by-browser'),
        ),
        isTrue,
      );
      expect(
        service.shouldFallbackToRedirect(
          FirebaseAuthException(
            code: 'internal-error',
            message: 'Cross-Origin-Opener-Policy blocked popup',
          ),
        ),
        isTrue,
      );
      expect(
        service.shouldFallbackToRedirect(
          FirebaseAuthException(code: 'popup-closed-by-user'),
        ),
        isFalse,
      );
      expect(
        service.shouldFallbackToRedirect(
          FirebaseAuthException(
            code: 'internal-error',
            message: 'INVALID_APP_CREDENTIAL',
          ),
        ),
        isFalse,
      );
      expect(
        service.shouldFallbackToRedirect(
          StateError('popup blocked by browser'),
        ),
        isTrue,
      );
      expect(
        service.shouldFallbackToRedirect(
          StateError('cancelled-popup-request popup blocked'),
        ),
        isFalse,
      );
      expect(service.shouldFallbackToRedirect(StateError('other')), isFalse);
    });
  });

  group('annulation, App Check et extensions', () {
    test('détecte les annulations utilisateur', () {
      for (final code in <String>[
        'popup-closed-by-user',
        'cancelled-popup-request',
        'cancelled',
        'user-cancelled',
      ]) {
        expect(
          service.isUserCancelled(FirebaseAuthException(code: code)),
          isTrue,
          reason: code,
        );
      }
      expect(
        service.isUserCancelled(StateError('closed-by-user')),
        isTrue,
      );
      expect(service.isUserCancelled(StateError('other')), isFalse);
    });

    test('détecte App Check uniquement sur Firebase internal-error', () {
      expect(service.isLikelyAppCheckEnforcement(StateError('app check')), isFalse);
      expect(
        service.isLikelyAppCheckEnforcement(
          FirebaseAuthException(code: 'invalid-email', message: 'app check'),
        ),
        isFalse,
      );
      expect(
        service.isLikelyAppCheckEnforcement(
          FirebaseAuthException(
            code: 'internal-error',
            message: 'REQUEST_BLOCKED by AppCheck',
          ),
        ),
        isTrue,
      );

      appCheckActivationAttempted = true;
      appCheckActivationSucceeded = false;
      expect(
        service.isLikelyAppCheckEnforcement(
          FirebaseAuthException(code: 'internal-error', message: 'unknown'),
        ),
        isTrue,
      );
    });

    test('NullableStringExt filtre les valeurs nulles et vides', () {
      String? value;
      expect(value.isNotEmpty, isFalse);
      value = '';
      expect(value.isNotEmpty, isFalse);
      value = 'message';
      expect(value.isNotEmpty, isTrue);

      final shown = <String>[];
      String? nullValue;
      nullValue.showIfNotNull(shown.add);
      ''.showIfNotNull(shown.add);
      'ok'.showIfNotNull(shown.add);
      expect(shown, <String>['ok']);
    });

    test('exécute toutes les branches de logs sans exception', () {
      service.logAttempt('popup');
      service.logAttempt('popup', details: 'detail');
      service.logFallback('popup', 'redirect');
      service.logFallback('popup', 'redirect', reason: 'blocked');
      service.logSuccess('popup', null);
      service.logSuccess('popup', 'test@example.com');
      service.logError('popup', StateError('boom'));
      service.logError(
        'popup',
        FirebaseAuthException(code: 'internal-error', message: 'detail'),
        retryCount: 1,
      );
      service.logError(
        'popup',
        PlatformException(code: 'network_error', message: 'detail'),
      );
    });
  });
}
