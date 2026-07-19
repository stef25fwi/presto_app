import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_credit_service.dart';

void main() {
  group('SubscriptionCreditService appels distants', () {
    test('charge et convertit le snapshot retourné par le serveur', () async {
      final service = SubscriptionCreditService(
        caller: (name, parameters) async {
          expect(name, 'getMySubscriptionCredits');
          expect(parameters, isNull);
          return {
            'plan': 'ilipresto_plus',
            'period': '2026-07',
            'credits': {
              'pdf': {
                'used': 2,
                'limit': 5,
                'remaining': 3,
                'unlimited': false,
                'exhausted': false,
              },
            },
          };
        },
      );

      final snapshot = await service.getSnapshot();

      expect(snapshot.plan, 'ilipresto_plus');
      expect(snapshot.period, '2026-07');
      expect(snapshot[SubscriptionCreditKind.pdf].remaining, 3);
    });

    test('consomme un crédit avec le type et l identifiant attendus', () async {
      String? calledName;
      Map<String, dynamic>? calledParameters;
      final service = SubscriptionCreditService(
        caller: (name, parameters) async {
          calledName = name;
          calledParameters = parameters;
          return const {};
        },
      );

      await service.consume(
        kind: SubscriptionCreditKind.voiceAi,
        operationId: 'voice-operation',
      );

      expect(calledName, 'consumeSubscriptionCredit');
      expect(calledParameters, {
        'kind': 'voiceAi',
        'operationId': 'voice-operation',
      });
    });

    test('traduit un quota serveur avec les détails du crédit', () async {
      final service = SubscriptionCreditService(
        caller: (_, __) async => throw FirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'Quota PDF atteint',
          details: const {
            'kind': 'pdf',
            'used': '5',
            'limit': 5.9,
          },
        ),
      );

      await expectLater(
        service.consume(
          kind: SubscriptionCreditKind.textAi,
          operationId: 'quota-operation',
        ),
        throwsA(
          isA<SubscriptionQuotaExceededException>()
              .having((error) => error.message, 'message', 'Quota PDF atteint')
              .having((error) => error.kind, 'kind', SubscriptionCreditKind.pdf)
              .having((error) => error.used, 'used', 5)
              .having((error) => error.limit, 'limit', 5),
        ),
      );
    });

    test('utilise le type demandé et le message par défaut sans détail valide',
        () async {
      final service = SubscriptionCreditService(
        caller: (_, __) async => throw FirebaseFunctionsException(
          code: 'resource-exhausted',
          details: const {
            'kind': 'inconnu',
            'used': '1',
            'limit': '2',
          },
        ),
      );

      await expectLater(
        service.saveJourney(const {'step': 1}),
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
                SubscriptionCreditKind.journeys,
              )
              .having((error) => error.used, 'used', 1)
              .having((error) => error.limit, 'limit', 2),
        ),
      );
    });

    test('relaie les erreurs Cloud Functions qui ne sont pas des quotas',
        () async {
      final service = SubscriptionCreditService(
        caller: (_, __) async => throw FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'Action refusée',
        ),
      );

      await expectLater(
        service.deleteJourney('journey-forbidden'),
        throwsA(
          isA<FirebaseFunctionsException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });

    test('rembourse un crédit consommable et absorbe une panne compensatoire',
        () async {
      final calls = <Map<String, dynamic>?>[];
      final successfulService = SubscriptionCreditService(
        caller: (name, parameters) async {
          expect(name, 'refundSubscriptionCredit');
          calls.add(parameters);
          return const {};
        },
      );

      await successfulService.refund(
        kind: SubscriptionCreditKind.textAi,
        operationId: 'refund-ok',
      );

      expect(calls, [
        {'kind': 'textAi', 'operationId': 'refund-ok'},
      ]);

      final failingService = SubscriptionCreditService(
        caller: (_, __) async => throw StateError('serveur indisponible'),
      );

      await failingService.refund(
        kind: SubscriptionCreditKind.pdf,
        operationId: 'refund-failure',
      );
    });

    test('sauvegarde un parcours avec ou sans identifiant existant', () async {
      final parameters = <Map<String, dynamic>?>[];
      var index = 0;
      final service = SubscriptionCreditService(
        caller: (name, value) async {
          expect(name, 'saveMyJourney');
          parameters.add(value);
          index += 1;
          return {'journeyId': 'journey-$index'};
        },
      );

      final created = await service.saveJourney(
        const {'title': 'Nouveau parcours'},
      );
      final updated = await service.saveJourney(
        const {'title': 'Parcours modifié'},
        journeyId: 'journey-existing',
      );
      final blank = await service.saveJourney(
        const {'title': 'Sans identifiant'},
        journeyId: '   ',
      );

      expect(created, 'journey-1');
      expect(updated, 'journey-2');
      expect(blank, 'journey-3');
      expect(parameters[0], {
        'snapshot': {'title': 'Nouveau parcours'},
      });
      expect(parameters[1], {
        'snapshot': {'title': 'Parcours modifié'},
        'journeyId': 'journey-existing',
      });
      expect(parameters[2], {
        'snapshot': {'title': 'Sans identifiant'},
      });
    });

    test('liste uniquement les parcours valides et gère une réponse invalide',
        () async {
      final service = SubscriptionCreditService(
        caller: (name, parameters) async {
          expect(name, 'listMyJourneys');
          expect(parameters, isNull);
          return {
            'journeys': [
              <Object?, Object?>{
                'id': 'journey-1',
                'title': 'Parcours valide',
                'snapshot': <Object?, Object?>{'step': 2},
              },
              <String, dynamic>{'id': '', 'title': 'Sans identifiant'},
              'entrée invalide',
            ],
          };
        },
      );

      final journeys = await service.listJourneys();

      expect(journeys, hasLength(1));
      expect(journeys.single.id, 'journey-1');
      expect(journeys.single.snapshot, {'step': 2});

      final invalidService = SubscriptionCreditService(
        caller: (_, __) async => {'journeys': 'invalide'},
      );
      expect(await invalidService.listJourneys(), isEmpty);
    });

    test('supprime un parcours avec son identifiant', () async {
      String? calledName;
      Map<String, dynamic>? calledParameters;
      final service = SubscriptionCreditService(
        caller: (name, parameters) async {
          calledName = name;
          calledParameters = parameters;
          return const {};
        },
      );

      await service.deleteJourney('journey-delete');

      expect(calledName, 'deleteMyJourney');
      expect(calledParameters, {'journeyId': 'journey-delete'});
    });
  });
}
