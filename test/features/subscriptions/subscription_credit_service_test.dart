import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_credit_service.dart';

void main() {
  group('SubscriptionCreditStatus', () {
    test('normalise les valeurs et les libellés compacts', () {
      final finite = SubscriptionCreditStatus.fromMap({
        'used': '2',
        'limit': 5.9,
        'remaining': 3,
        'unlimited': false,
        'exhausted': false,
      });
      final unlimited = SubscriptionCreditStatus.fromMap({
        'unlimited': true,
      });
      final disabled = SubscriptionCreditStatus.fromMap(null);

      expect(finite.used, 2);
      expect(finite.limit, 5);
      expect(finite.remaining, 3);
      expect(finite.compactLabel, '3/5');
      expect(unlimited.compactLabel, '∞');
      expect(disabled.compactLabel, '0');
    });
  });

  group('SubscriptionCreditSnapshot', () {
    test('convertit les crédits et la prochaine remise à zéro', () {
      final snapshot = SubscriptionCreditSnapshot.fromMap({
        'plan': 'ilipresto_plus',
        'period': '2026-07',
        'freeAccessMode': true,
        'nextResetAt': '2026-08-01T00:00:00.000Z',
        'credits': {
          'pdf': {
            'used': 1,
            'limit': 5,
            'remaining': 4,
            'unlimited': false,
            'exhausted': false,
          },
          'voiceAi': {
            'used': 0,
            'limit': 999999,
            'remaining': 999999,
            'unlimited': true,
            'exhausted': false,
          },
        },
      });

      expect(snapshot.plan, 'ilipresto_plus');
      expect(snapshot.period, '2026-07');
      expect(snapshot.freeAccessMode, isTrue);
      expect(snapshot.nextResetAt?.toUtc(), DateTime.utc(2026, 8, 1));
      expect(snapshot[SubscriptionCreditKind.pdf].compactLabel, '4/5');
      expect(snapshot[SubscriptionCreditKind.voiceAi].compactLabel, '∞');
      expect(snapshot[SubscriptionCreditKind.textAi].exhausted, isFalse);
    });

    test('retourne un statut épuisé quand la clé est absente', () {
      const snapshot = SubscriptionCreditSnapshot(
        plan: 'free',
        period: '',
        freeAccessMode: false,
        nextResetAt: null,
        credits: <SubscriptionCreditKind, SubscriptionCreditStatus>{},
      );

      final missing = snapshot[SubscriptionCreditKind.activeOffers];
      expect(missing.used, 0);
      expect(missing.limit, 0);
      expect(missing.remaining, 0);
      expect(missing.exhausted, isTrue);
    });

    test('applique les valeurs par défaut sur une réponse vide', () {
      final snapshot = SubscriptionCreditSnapshot.fromMap(const {});

      expect(snapshot.plan, 'free');
      expect(snapshot.period, isEmpty);
      expect(snapshot.freeAccessMode, isFalse);
      expect(snapshot.nextResetAt, isNull);
      for (final kind in SubscriptionCreditKind.values) {
        expect(snapshot[kind].used, 0);
        expect(snapshot[kind].limit, 0);
      }
    });
  });

  group('SavedJourneyRecord', () {
    test('convertit les métadonnées et le snapshot', () {
      final record = SavedJourneyRecord.fromMap({
        'id': 'journey-1',
        'title': 'Mon parcours',
        'activity': 'Jardinage',
        'currentStatus': 'independant',
        'region': 'Guadeloupe',
        'createdAtMillis': 1,
        'updatedAtMillis': '2000',
        'snapshot': <Object?, Object?>{'step': 3},
      });

      expect(record.id, 'journey-1');
      expect(record.title, 'Mon parcours');
      expect(record.activity, 'Jardinage');
      expect(record.currentStatus, 'independant');
      expect(record.region, 'Guadeloupe');
      expect(record.createdAt, DateTime.fromMillisecondsSinceEpoch(1));
      expect(record.updatedAt, DateTime.fromMillisecondsSinceEpoch(2000));
      expect(record.snapshot, {'step': 3});
    });

    test('ignore les dates nulles ou négatives', () {
      final record = SavedJourneyRecord.fromMap({
        'createdAtMillis': 0,
        'updatedAtMillis': -1,
      });

      expect(record.createdAt, isNull);
      expect(record.updatedAt, isNull);
      expect(record.snapshot, isEmpty);
    });

    test('normalise les valeurs absentes et les snapshots non map', () {
      final record = SavedJourneyRecord.fromMap({
        'id': null,
        'snapshot': 'invalide',
      });

      expect(record.id, isEmpty);
      expect(record.title, isEmpty);
      expect(record.activity, isEmpty);
      expect(record.currentStatus, isEmpty);
      expect(record.region, isEmpty);
      expect(record.snapshot, isEmpty);
    });
  });

  group('SubscriptionCreditService garde-fous', () {
    final service = SubscriptionCreditService();

    test('refuse la consommation directe des parcours', () async {
      await expectLater(
        service.consume(
          kind: SubscriptionCreditKind.journeys,
          operationId: 'journey-op',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('refuse la consommation directe des annonces actives', () async {
      await expectLater(
        service.consume(
          kind: SubscriptionCreditKind.activeOffers,
          operationId: 'offer-op',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('ignore le remboursement des crédits non consommables', () async {
      await service.refund(
        kind: SubscriptionCreditKind.journeys,
        operationId: 'journey-refund',
      );
      await service.refund(
        kind: SubscriptionCreditKind.activeOffers,
        operationId: 'offer-refund',
      );
    });
  });

  test('l exception de quota conserve ses informations', () {
    const error = SubscriptionQuotaExceededException(
      message: 'Quota atteint',
      kind: SubscriptionCreditKind.pdf,
      used: 5,
      limit: 5,
    );

    expect(error.toString(), 'Quota atteint');
    expect(error.kind, SubscriptionCreditKind.pdf);
    expect(error.used, 5);
    expect(error.limit, 5);
  });

  test('les identifiants d opération sont préfixés et uniques', () {
    final first = SubscriptionCreditService.newOperationId('pdf');
    final second = SubscriptionCreditService.newOperationId('voice');

    expect(first, startsWith('pdf_'));
    expect(second, startsWith('voice_'));
    expect(first, isNot(second));
  });
}