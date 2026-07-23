import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

void main() {
  test('construit directement les états gratuit et payant', () {
    final freeState = AppUserSubscriptionState.free();
    expect(freeState.plan, SubscriptionPlan.free);
    expect(freeState.status, SubscriptionStatus.inactive);
    expect(freeState.subscriptionExpiresAt, isNull);
    expect(freeState.phoneVerified, isFalse);
    expect(freeState.proVerified, isFalse);

    final expiresAt = DateTime.utc(2026, 12, 31, 23, 59);
    final paidState = AppUserSubscriptionState(
      plan: SubscriptionPlan.ilipro,
      status: SubscriptionStatus.active,
      subscriptionExpiresAt: expiresAt,
      phoneVerified: true,
      proVerified: true,
    );

    expect(paidState.plan, SubscriptionPlan.ilipro);
    expect(paidState.status, SubscriptionStatus.active);
    expect(paidState.subscriptionExpiresAt, expiresAt);
    expect(paidState.phoneVerified, isTrue);
    expect(paidState.proVerified, isTrue);
    expect(paidState.toFirestoreSeedMap(), <String, dynamic>{
      'subscriptionPlan': 'ilipro',
      'subscriptionStatus': 'active',
      'subscriptionExpiresAt': expiresAt,
      'phoneVerified': true,
      'proVerified': true,
    });
  });
}
