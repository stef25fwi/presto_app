import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/auth/services/auth_service.dart';

void main() {
  test('normalise l email et utilise le reset backend injecté', () async {
    String? receivedEmail;
    final service = EmailAuthService(
      backendPasswordReset: (email) async {
        receivedEmail = email;
      },
    );

    await service.sendPasswordResetEmail('  Personne@Example.COM  ');

    expect(receivedEmail, 'personne@example.com');
  });

  test('utilise le reset natif injecté lorsque le backend échoue', () async {
    String? nativeEmail;
    final service = EmailAuthService(
      backendPasswordReset: (_) async {
        throw StateError('backend indisponible');
      },
      nativePasswordReset: (email) async {
        nativeEmail = email;
      },
    );

    await service.sendPasswordResetEmail('  Secours@Example.COM ');

    expect(nativeEmail, 'secours@example.com');
  });

  test('délègue la synchronisation email à l action injectée', () async {
    var calls = 0;
    final service = EmailAuthService(
      syncEmailVerification: () async {
        calls += 1;
        return true;
      },
    );

    final verified = await service.syncCurrentUserEmailVerificationState();

    expect(verified, isTrue);
    expect(calls, 1);
  });

  test('délègue la demande de vérification pour un utilisateur connecté',
      () async {
    var calls = 0;
    final service = EmailAuthService(
      hasCurrentUser: () => true,
      requestEmailVerification: () async {
        calls += 1;
      },
    );

    await service.requestEmailVerificationEmail();

    expect(calls, 1);
  });
}
