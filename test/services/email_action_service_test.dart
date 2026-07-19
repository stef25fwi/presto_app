import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/email_action_service.dart';

void main() {
  tearDown(EmailActionService.resetCallableInvokerForTest);

  test('normalise l email et appelle le reset backend', () async {
    String? functionName;
    Map<String, dynamic>? payload;
    EmailActionService.setCallableInvokerForTest((name, data) async {
      functionName = name;
      payload = data;
    });

    await EmailActionService.requestPasswordResetEmail(
      '  Personne@Example.com  ',
    );

    expect(functionName, 'requestPasswordResetEmail');
    expect(payload, <String, dynamic>{'email': 'Personne@Example.com'});
  });

  test('demande une vérification email sans payload', () async {
    String? functionName;
    Map<String, dynamic>? payload = <String, dynamic>{};
    EmailActionService.setCallableInvokerForTest((name, data) async {
      functionName = name;
      payload = data;
    });

    await EmailActionService.requestEmailVerificationEmail();

    expect(functionName, 'requestEmailVerificationEmail');
    expect(payload, isNull);
  });

  test('signale le changement de mot de passe avec un timestamp courant',
      () async {
    String? functionName;
    Map<String, dynamic>? payload;
    EmailActionService.setCallableInvokerForTest((name, data) async {
      functionName = name;
      payload = data;
    });
    final before = DateTime.now().millisecondsSinceEpoch;

    await EmailActionService.reportPasswordChanged();

    final after = DateTime.now().millisecondsSinceEpoch;
    expect(functionName, 'reportPasswordChanged');
    expect(payload, isNotNull);
    expect(payload!['changedAt'], isA<int>());
    expect(payload!['changedAt'] as int, inInclusiveRange(before, after));
  });

  test('propage les erreurs du backend', () async {
    EmailActionService.setCallableInvokerForTest((_, __) async {
      throw StateError('backend indisponible');
    });

    await expectLater(
      EmailActionService.requestEmailVerificationEmail(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'backend indisponible',
        ),
      ),
    );
  });
}
