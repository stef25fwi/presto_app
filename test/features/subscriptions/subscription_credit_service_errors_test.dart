import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_credit_service.dart';

void main() {
  group('SubscriptionCreditService error mapping', () {
    test('maps resource-exhausted details to quota exception', () async {
      final service = SubscriptionCreditService(
        caller: (name, parameters) async {
          throw FirebaseFunctionsException(
            code: 'resource-exhausted',
            message: 'Quota PDF épuisé',
            details: <String, dynamic>{
              'kind': 'pdf',
              'used': 2,
              'limit': 2,
            },
          );
        },
      );

      await expectLater(
        service.consume(
          kind: SubscriptionCreditKind.pdf,
          operationId: 'pdf-op',
        ),
        throwsA(
          isA<SubscriptionQuotaExceededException>()
              .having((error) => error.message, 'message', 'Quota PDF épuisé')
              .having(
                (error) => error.kind,
                'kind',
                SubscriptionCreditKind.pdf,
              )
              .having((error) => error.used, 'used', 2)
              .having((error) => error.limit, 'limit', 2),
        ),
      );
    });

    test('uses quota kind and default message when details are incomplete', () async {
      final service = SubscriptionCreditService(
        caller: (name, parameters) async {
          throw FirebaseFunctionsException(
            code: 'resource-exhausted',
            message: '   ',
            details: const <String, dynamic>{
              'used': '3',
              'limit': '3',
            },
          );
        },
      );

      await expectLater(
        service.consume(
          kind: SubscriptionCreditKind.voiceAi,
          operationId: 'voice-op',
        ),
        throwsA(
          isA<SubscriptionQuotaExceededException>()
              .having(
                (error) => error.message,
                'message',
                'Votre crédit est épuisé. Consultez les offres disponibles.',
              )
              .having(
                (error) => error.kind,
                'kind',
                SubscriptionCreditKind.voiceAi,
              )
              .having((error) => error.used, 'used', 3)
              .having((error) => error.limit, 'limit', 3),
        ),
      );
    });

    test('keeps unknown Firebase errors unchanged', () async {
      final original = FirebaseFunctionsException(
        code: 'internal',
        message: 'backend unavailable',
      );
      final service = SubscriptionCreditService(
        caller: (name, parameters) async => throw original,
      );

      await expectLater(
        service.getSnapshot(),
        throwsA(same(original)),
      );
    });

    test('ignores refund failures after attempting the callable', () async {
      final calls = <String>[];
      final service = SubscriptionCreditService(
        caller: (name, parameters) async {
          calls.add(name);
          throw StateError('refund failed');
        },
      );

      await service.refund(
        kind: SubscriptionCreditKind.textAi,
        operationId: 'refund-op',
      );

      expect(calls, <String>['refundSubscriptionCredit']);
    });
  });
}
