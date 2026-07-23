import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/journey_entitlements_service.dart';
import 'package:presto_app/features/subscriptions/subscription_credit_service.dart';

class _SuccessfulCreditService extends SubscriptionCreditService {
  _SuccessfulCreditService(this.snapshot);

  final SubscriptionCreditSnapshot snapshot;
  int calls = 0;

  @override
  Future<SubscriptionCreditSnapshot> getSnapshot() async {
    calls += 1;
    return snapshot;
  }
}

SubscriptionCreditStatus _status(int used, int limit) {
  return SubscriptionCreditStatus(
    used: used,
    limit: limit,
    remaining: limit - used,
    unlimited: false,
    exhausted: used >= limit,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  test('charge réellement le snapshot de crédits sur le chemin nominal', () async {
    final creditService = _SuccessfulCreditService(
      SubscriptionCreditSnapshot(
        plan: 'ilipresto_plus',
        period: '2026-07',
        freeAccessMode: false,
        nextResetAt: DateTime.utc(2026, 8),
        credits: <SubscriptionCreditKind, SubscriptionCreditStatus>{
          SubscriptionCreditKind.journeys: _status(3, 5),
          SubscriptionCreditKind.pdf: _status(2, 5),
        },
      ),
    );
    final service = JourneyEntitlementsService(creditService: creditService);

    expect(await service.getLocalSavesUsedThisMonth(), 3);
    expect(await service.getPdfExportsUsedThisMonth(), 2);
    expect(creditService.calls, 2);
  });
}
