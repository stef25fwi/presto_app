import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/user_profile_bootstrap_service.dart';

void main() {
  group('UserProfileBootstrapException', () {
    test('exposes App Check and timeout classifications', () {
      final unavailable = UserProfileBootstrapException(
        'app-check-unavailable',
        'App Check unavailable',
      );
      final missing = UserProfileBootstrapException(
        'app-check-token-missing',
        'App Check token missing',
      );
      final timeout = UserProfileBootstrapException(
        'profile-access-timeout',
        'Timed out',
      );
      final generic = UserProfileBootstrapException(
        'profile-access-failed',
        'Failed',
      );

      expect(unavailable.isAppCheckFailure, isTrue);
      expect(missing.isAppCheckFailure, isTrue);
      expect(timeout.isAppCheckFailure, isFalse);
      expect(timeout.isTimeout, isTrue);
      expect(generic.isTimeout, isFalse);
    });

    test('toString includes code, message and optional cause', () {
      final withoutCause = UserProfileBootstrapException(
        'profile-access-failed',
        'Impossible',
      );
      final withCause = UserProfileBootstrapException(
        'profile-access-failed',
        'Impossible',
        cause: StateError('boom'),
      );

      expect(
        withoutCause.toString(),
        'UserProfileBootstrapException(profile-access-failed): Impossible',
      );
      expect(withCause.toString(), contains('cause=Bad state: boom'));
    });
  });

  group('profile sync user-facing mapping', () {
    test('keeps an existing normalized exception classification', () {
      final appCheck = UserProfileBootstrapException(
        'app-check-token-missing',
        'missing',
      );
      final timeout = UserProfileBootstrapException(
        'profile-access-timeout',
        'timeout',
      );

      expect(
        UserProfileBootstrapService.userFacingProfileSyncMessage(appCheck),
        contains('vérification de sécurité web'),
      );
      expect(
        UserProfileBootstrapService.userFacingProfileSyncMessage(timeout),
        contains('synchronisation du profil a expiré'),
      );
    });

    test('normalizes TimeoutException and App Check-shaped errors', () {
      expect(
        UserProfileBootstrapService.userFacingProfileSyncMessage(
          TimeoutException('late'),
        ),
        contains('synchronisation du profil a expiré'),
      );
      expect(
        UserProfileBootstrapService.userFacingProfileSyncMessage(
          StateError('firebase_app_check unavailable'),
        ),
        contains('vérification de sécurité web'),
      );
      expect(
        UserProfileBootstrapService.userFacingProfileSyncMessage(
          StateError('APP CHECK unavailable'),
        ),
        contains('vérification de sécurité web'),
      );
    });

    test('falls back to the generic synchronization warning', () {
      expect(
        UserProfileBootstrapService.userFacingProfileSyncMessage(),
        contains("profil n'a pas pu être synchronisé"),
      );
      expect(
        UserProfileBootstrapService.userFacingProfileSyncMessage(
          StateError('network'),
        ),
        contains("profil n'a pas pu être synchronisé"),
      );
    });

    test('public App Check classifier follows normalization rules', () {
      expect(
        UserProfileBootstrapService.isAppCheckFailure(
          UserProfileBootstrapException(
            'app-check-unavailable',
            'unavailable',
          ),
        ),
        isTrue,
      );
      expect(
        UserProfileBootstrapService.isAppCheckFailure(
          StateError('app_check token error'),
        ),
        isTrue,
      );
      expect(
        UserProfileBootstrapService.isAppCheckFailure(
          TimeoutException('late'),
        ),
        isFalse,
      );
    });
  });

  group('Firestore retry policy helpers', () {
    test('classifies retryable Firestore status codes', () {
      for (final code in <String>[
        'unavailable',
        'deadline-exceeded',
        'aborted',
        'internal',
        'cancelled',
        'resource-exhausted',
        'unknown-future-code',
      ]) {
        expect(
          UserProfileBootstrapService.isRetryableFirestoreCodeForTest(code),
          isTrue,
          reason: code,
        );
      }
    });

    test('classifies terminal Firestore status codes', () {
      for (final code in <String>[
        'permission-denied',
        'unauthenticated',
        'not-found',
        'already-exists',
        'invalid-argument',
        'failed-precondition',
      ]) {
        expect(
          UserProfileBootstrapService.isRetryableFirestoreCodeForTest(code),
          isFalse,
          reason: code,
        );
      }
    });

    test('uses exponential retry backoff and rejects negative attempts', () {
      expect(
        UserProfileBootstrapService.retryBackoffForAttemptForTest(0),
        const Duration(seconds: 1),
      );
      expect(
        UserProfileBootstrapService.retryBackoffForAttemptForTest(1),
        const Duration(seconds: 2),
      );
      expect(
        UserProfileBootstrapService.retryBackoffForAttemptForTest(2),
        const Duration(seconds: 4),
      );
      expect(
        () => UserProfileBootstrapService.retryBackoffForAttemptForTest(-1),
        throwsArgumentError,
      );
    });
  });

  test('user document path remains canonical', () {
    expect(
      UserProfileBootstrapService.userDocumentPathForTest('user-42'),
      'users/user-42',
    );
  });

  test('bootstrap memo reset is safe and repeatable', () {
    UserProfileBootstrapService.resetBootstrapMemoForTests();
    UserProfileBootstrapService.resetBootstrapMemoForTests();
  });
}
