import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/auth/services/auth_service.dart';

void main() {
  test('normalise l email avant le reset backend', () async {
    String? receivedEmail;
    final service = EmailAuthService(
      backendPasswordReset: (email) async => receivedEmail = email,
      nativePasswordReset: (_) async => fail('fallback inattendu'),
    );

    await service.sendPasswordResetEmail('  USER@Example.COM  ');

    expect(receivedEmail, 'user@example.com');
  });

  test('utilise le fallback natif si le backend échoue', () async {
    String? fallbackEmail;
    final service = EmailAuthService(
      backendPasswordReset: (_) async =>
          throw StateError('backend indisponible'),
      nativePasswordReset: (email) async => fallbackEmail = email,
    );

    await service.sendPasswordResetEmail('personne@example.com');

    expect(fallbackEmail, 'personne@example.com');
  });

  test('refuse un email vide avant toute action', () async {
    var calls = 0;
    final service = EmailAuthService(
      backendPasswordReset: (_) async => calls += 1,
      nativePasswordReset: (_) async => calls += 1,
    );

    await expectLater(
      service.sendPasswordResetEmail('   '),
      throwsA(
        isA<FirebaseAuthException>().having(
          (error) => error.code,
          'code',
          'missing-email',
        ),
      ),
    );
    expect(calls, 0);
  });

  test(
    'demande l email de vérification pour un utilisateur connecté',
    () async {
      var calls = 0;
      final service = EmailAuthService(
        hasCurrentUser: () => true,
        requestEmailVerification: () async => calls += 1,
      );

      await service.requestEmailVerificationEmail();

      expect(calls, 1);
    },
  );

  test('refuse la vérification sans utilisateur connecté', () async {
    var calls = 0;
    final service = EmailAuthService(
      hasCurrentUser: () => false,
      requestEmailVerification: () async => calls += 1,
    );

    await expectLater(
      service.requestEmailVerificationEmail(),
      throwsA(
        isA<FirebaseAuthException>().having(
          (error) => error.code,
          'code',
          'user-token-expired',
        ),
      ),
    );
    expect(calls, 0);
  });

  test('retourne le résultat de synchronisation injecté', () async {
    final verifiedService = EmailAuthService(
      syncEmailVerification: () async => true,
    );
    final unverifiedService = EmailAuthService(
      syncEmailVerification: () async => false,
    );

    expect(
      await verifiedService.syncCurrentUserEmailVerificationState(),
      isTrue,
    );
    expect(
      await unverifiedService.syncCurrentUserEmailVerificationState(),
      isFalse,
    );
  });
}
