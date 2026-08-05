import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/user_profile_bootstrap_service.dart';

void main() {
  group('UserProfileBootstrapException', () {
    test('exposes app-check and timeout classifications', () {
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
        'Profile access timed out',
      );
      final generic = UserProfileBootstrapException(
        'profile-access-failed',
        'Profile access failed',
      );

      expect(unavailable.isAppCheckFailure, isTrue);
      expect(missing.isAppCheckFailure, isTrue);
      expect(timeout.isTimeout, isTrue);
      expect(generic.isAppCheckFailure, isFalse);
      expect(generic.isTimeout, isFalse);
    });

    test('toString includes the cause only when present', () {
      final withoutCause = UserProfileBootstrapException(
        'profile-access-failed',
        'Profile access failed',
      );
      final withCause = UserProfileBootstrapException(
        'profile-access-failed',
        'Profile access failed',
        cause: StateError('offline'),
      );

      expect(
        withoutCause.toString(),
        'UserProfileBootstrapException(profile-access-failed): Profile access failed',
      );
      expect(withCause.toString(), contains('cause=Bad state: offline'));
    });
  });

  group('UserProfileBootstrapService error mapping', () {
    test('returns the dedicated App Check warning', () {
      final error = UserProfileBootstrapException(
        'app-check-token-missing',
        'missing token',
      );

      expect(UserProfileBootstrapService.isAppCheckFailure(error), isTrue);
      expect(
        UserProfileBootstrapService.userFacingProfileSyncMessage(error),
        contains('vérification de sécurité web'),
      );
    });

    test('normalizes timeout errors to the timeout warning', () {
      expect(
        UserProfileBootstrapService.userFacingProfileSyncMessage(
          TimeoutException('slow network'),
        ),
        contains('synchronisation du profil a expiré'),
      );
    });

    test('recognizes raw App Check errors', () {
      final error = StateError('firebase_app_check unavailable');

      expect(UserProfileBootstrapService.isAppCheckFailure(error), isTrue);
      expect(
        UserProfileBootstrapService.userFacingProfileSyncMessage(error),
        contains('vérification de sécurité web'),
      );
    });

    test('falls back to the generic warning for unknown errors and null', () {
      expect(
        UserProfileBootstrapService.userFacingProfileSyncMessage(
          StateError('offline'),
        ),
        contains("profil n'a pas pu être synchronisé"),
      );
      expect(
        UserProfileBootstrapService.userFacingProfileSyncMessage(),
        contains("profil n'a pas pu être synchronisé"),
      );
    });

    test('unknown Firestore codes remain retryable by default', () {
      expect(
        UserProfileBootstrapService.isRetryableFirestoreCodeForTest(
          'future-transient-code',
        ),
        isTrue,
      );
    });

    test('memo reset is safe and repeatable', () {
      UserProfileBootstrapService.resetBootstrapMemoForTests();
      UserProfileBootstrapService.resetBootstrapMemoForTests();
    });
  });
}
