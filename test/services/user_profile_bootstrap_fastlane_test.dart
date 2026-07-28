import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/user_profile_bootstrap_service.dart';

void main() {
  tearDown(UserProfileBootstrapService.resetBootstrapMemoForTests);

  test('expose le chemin Firestore utilisateur attendu', () {
    expect(
      UserProfileBootstrapService.userDocumentPathForTest('user-42'),
      'users/user-42',
    );
  });

  test('traduit les erreurs App Check en avertissement web', () {
    final error = UserProfileBootstrapException(
      'app-check-token-missing',
      'token missing',
    );

    expect(error.isAppCheckFailure, isTrue);
    expect(error.isTimeout, isFalse);
    expect(UserProfileBootstrapService.isAppCheckFailure(error), isTrue);
    expect(
      UserProfileBootstrapService.userFacingProfileSyncMessage(error),
      contains('vérification de sécurité web'),
    );
  });

  test('normalise un timeout en message de synchronisation expirée', () {
    expect(
      UserProfileBootstrapService.userFacingProfileSyncMessage(
        TimeoutException('slow profile'),
      ),
      contains('synchronisation du profil a expiré'),
    );
  });

  test('normalise les messages App Check génériques', () {
    expect(
      UserProfileBootstrapService.isAppCheckFailure(
        StateError('Firebase App Check unavailable'),
      ),
      isTrue,
    );
    expect(
      UserProfileBootstrapService.isAppCheckFailure(
        StateError('firebase_app_check unavailable'),
      ),
      isTrue,
    );
  });

  test('retourne le message générique pour une erreur inconnue', () {
    expect(
      UserProfileBootstrapService.userFacingProfileSyncMessage(
        StateError('offline'),
      ),
      contains("profil n'a pas pu être synchronisé"),
    );
  });

  test('classe les codes Firestore retryables et définitifs', () {
    for (final code in <String>[
      'unavailable',
      'deadline-exceeded',
      'aborted',
      'internal',
      'cancelled',
      'resource-exhausted',
      'unknown-transient',
    ]) {
      expect(
        UserProfileBootstrapService.isRetryableFirestoreCodeForTest(code),
        isTrue,
        reason: code,
      );
    }

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

  test('calcule le backoff exponentiel et refuse les tentatives négatives', () {
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

  test('toString conserve le code, le message et la cause', () {
    final error = UserProfileBootstrapException(
      'profile-access-failed',
      'Accès impossible',
      cause: StateError('offline'),
    );

    expect(error.toString(), contains('profile-access-failed'));
    expect(error.toString(), contains('Accès impossible'));
    expect(error.toString(), contains('offline'));
  });
}
