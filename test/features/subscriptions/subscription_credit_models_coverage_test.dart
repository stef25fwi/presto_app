import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_credit_service.dart';

void main() {
  group('SubscriptionCreditStatus', () {
    test('normalise les valeurs numériques et les libellés compacts', () {
      final unlimited = SubscriptionCreditStatus.fromMap({
        'used': '2',
        'limit': 10.9,
        'remaining': '8',
        'unlimited': true,
        'exhausted': false,
      });
      final unavailable = SubscriptionCreditStatus.fromMap(null);
      final limited = SubscriptionCreditStatus.fromMap({
        'used': 1,
        'limit': 5,
        'remaining': 4,
      });

      expect(unlimited.used, 2);
      expect(unlimited.limit, 10);
      expect(unlimited.remaining, 8);
      expect(unlimited.compactLabel, '∞');
      expect(unavailable.compactLabel, '0');
      expect(limited.compactLabel, '4/5');
    });
  });

  group('SubscriptionCreditSnapshot', () {
    test('construit tous les crédits et conserve le fallback absent', () {
      final snapshot = SubscriptionCreditSnapshot.fromMap({
        'plan': 'ilipresto+',
        'period': '2026-08',
        'freeAccessMode': true,
        'nextResetAt': '2026-09-01T00:00:00.000Z',
        'credits': {
          'pdf': {
            'used': 2,
            'limit': 5,
            'remaining': 3,
            'unlimited': false,
            'exhausted': false,
          },
        },
      });

      expect(snapshot.plan, 'ilipresto+');
      expect(snapshot.period, '2026-08');
      expect(snapshot.freeAccessMode, isTrue);
      expect(snapshot.nextResetAt, DateTime.utc(2026, 9));
      expect(snapshot[SubscriptionCreditKind.pdf].remaining, 3);
      expect(snapshot[SubscriptionCreditKind.voiceAi].limit, 0);
      expect(snapshot[SubscriptionCreditKind.voiceAi].exhausted, isFalse);
    });

    test('applique les valeurs par défaut aux données invalides', () {
      final snapshot = SubscriptionCreditSnapshot.fromMap({
        'nextResetAt': 'date-invalide',
        'credits': 'invalide',
      });

      expect(snapshot.plan, 'free');
      expect(snapshot.period, isEmpty);
      expect(snapshot.freeAccessMode, isFalse);
      expect(snapshot.nextResetAt, isNull);
      expect(snapshot[SubscriptionCreditKind.activeOffers].compactLabel, '0');
    });
  });

  group('SavedJourneyRecord', () {
    test('normalise les champs, dates et snapshot', () {
      final record = SavedJourneyRecord.fromMap({
        'id': 42,
        'title': 'Mon parcours',
        'activity': 'Plomberie',
        'currentStatus': 'draft',
        'region': 'Guadeloupe',
        'createdAtMillis': 1000,
        'updatedAtMillis': '2000',
        'snapshot': {'step': 3},
      });

      expect(record.id, '42');
      expect(record.title, 'Mon parcours');
      expect(record.activity, 'Plomberie');
      expect(record.currentStatus, 'draft');
      expect(record.region, 'Guadeloupe');
      expect(record.createdAt, DateTime.fromMillisecondsSinceEpoch(1000));
      expect(record.updatedAt, DateTime.fromMillisecondsSinceEpoch(2000));
      expect(record.snapshot, {'step': 3});
    });

    test('ignore les dates non positives et les snapshots invalides', () {
      final record = SavedJourneyRecord.fromMap({
        'createdAtMillis': 0,
        'updatedAtMillis': -1,
        'snapshot': 'invalide',
      });

      expect(record.createdAt, isNull);
      expect(record.updatedAt, isNull);
      expect(record.snapshot, isEmpty);
    });
  });

  test('SubscriptionQuotaExceededException expose son message', () {
    const error = SubscriptionQuotaExceededException(
      message: 'Crédit épuisé',
      kind: SubscriptionCreditKind.pdf,
      used: 5,
      limit: 5,
    );

    expect(error.toString(), 'Crédit épuisé');
    expect(error.kind, SubscriptionCreditKind.pdf);
    expect(error.used, 5);
    expect(error.limit, 5);
  });

  test('newOperationId inclut le préfixe et varie', () async {
    final first = SubscriptionCreditService.newOperationId('pdf');
    await Future<void>.delayed(const Duration(microseconds: 2));
    final second = SubscriptionCreditService.newOperationId('pdf');

    expect(first, startsWith('pdf_'));
    expect(second, startsWith('pdf_'));
    expect(second, isNot(first));
  });
}
