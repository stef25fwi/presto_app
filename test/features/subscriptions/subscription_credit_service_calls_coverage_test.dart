import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_credit_service.dart';

void main() {
  group('SubscriptionCreditService calls', () {
    test('getSnapshot and journey operations normalize caller payloads', () async {
      final calls = <String>[];
      final service = SubscriptionCreditService(
        caller: (name, parameters) async {
          calls.add(name);
          switch (name) {
            case 'getMySubscriptionCredits':
              return {
                'plan': 'plus',
                'period': '2026-08',
                'credits': <String, dynamic>{},
              };
            case 'saveMyJourney':
              expect(parameters?['snapshot'], {'step': 2});
              expect(parameters?['journeyId'], 'journey-1');
              return {'journeyId': 'journey-1'};
            case 'listMyJourneys':
              return {
                'journeys': [
                  {
                    'id': 'journey-1',
                    'title': 'Projet',
                    'activity': 'Jardinage',
                    'currentStatus': 'draft',
                    'region': 'GP',
                    'snapshot': {'step': 2},
                  },
                  {'id': ''},
                  'ignored',
                ],
              };
            case 'deleteMyJourney':
              expect(parameters, {'journeyId': 'journey-1'});
              return <String, dynamic>{};
          }
          throw StateError(name);
        },
      );

      final snapshot = await service.getSnapshot();
      expect(snapshot.plan, 'plus');

      expect(
        await service.saveJourney({'step': 2}, journeyId: 'journey-1'),
        'journey-1',
      );
      final journeys = await service.listJourneys();
      expect(journeys, hasLength(1));
      expect(journeys.single.id, 'journey-1');
      await service.deleteJourney('journey-1');

      expect(calls, [
        'getMySubscriptionCredits',
        'saveMyJourney',
        'listMyJourneys',
        'deleteMyJourney',
      ]);
    });

    test('consume rejects non-consumable kinds and forwards consumable kind', () async {
      Map<String, dynamic>? sent;
      final service = SubscriptionCreditService(
        caller: (name, parameters) async {
          expect(name, 'consumeSubscriptionCredit');
          sent = parameters;
          return <String, dynamic>{};
        },
      );

      expect(
        () => service.consume(
          kind: SubscriptionCreditKind.journeys,
          operationId: 'op-blocked',
        ),
        throwsArgumentError,
      );
      await service.consume(
        kind: SubscriptionCreditKind.pdf,
        operationId: 'op-pdf',
      );
      expect(sent, {'kind': 'pdf', 'operationId': 'op-pdf'});
    });

    test('refund ignores non-refundable kinds and swallows caller failures', () async {
      var calls = 0;
      final service = SubscriptionCreditService(
        caller: (name, parameters) async {
          calls += 1;
          expect(name, 'refundSubscriptionCredit');
          throw StateError('temporary failure');
        },
      );

      await service.refund(
        kind: SubscriptionCreditKind.activeOffers,
        operationId: 'op-ignored',
      );
      expect(calls, 0);

      await service.refund(
        kind: SubscriptionCreditKind.voiceAi,
        operationId: 'op-refund',
      );
      expect(calls, 1);
    });

    test('listJourneys returns empty list for malformed payload', () async {
      final service = SubscriptionCreditService(
        caller: (name, parameters) async => {'journeys': 'invalid'},
      );

      expect(await service.listJourneys(), isEmpty);
    });
  });
}
