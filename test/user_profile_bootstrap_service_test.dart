import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/user_profile_bootstrap_service.dart';

void main() {
  group('UserProfileBootstrapService retry policy', () {
    test('codes retryables conformes', () {
      const retryable = <String>[
        'unavailable',
        'deadline-exceeded',
        'aborted',
        'internal',
        'cancelled',
        'resource-exhausted',
      ];

      for (final code in retryable) {
        expect(
          UserProfileBootstrapService.isRetryableFirestoreCodeForTest(code),
          isTrue,
          reason: 'Expected code $code to be retryable',
        );
      }
    });

    test('codes fail-fast conformes', () {
      const failFast = <String>[
        'permission-denied',
        'unauthenticated',
        'not-found',
        'already-exists',
        'invalid-argument',
        'failed-precondition',
      ];

      for (final code in failFast) {
        expect(
          UserProfileBootstrapService.isRetryableFirestoreCodeForTest(code),
          isFalse,
          reason: 'Expected code $code to be fail-fast',
        );
      }
    });

    test('backoff exponentiel 1s, 2s, 4s', () {
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
    });

    test('attempt negative invalide', () {
      expect(
        () => UserProfileBootstrapService.retryBackoffForAttemptForTest(-1),
        throwsArgumentError,
      );
    });
  });
}
