import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_models.dart';

void main() {
  test('construit directement un état utilisateur payant complet', () {
    final expiresAt = DateTime.utc(2026, 12, 31, 23, 59);
    final state = AppUserSubscriptionState(
      plan: SubscriptionPlan.ilipro,
      status: SubscriptionStatus.active,
      subscriptionExpiresAt: expiresAt,
      phoneVerified: true,
      proVerified: true,
    );

    expect(state.plan, SubscriptionPlan.ilipro);
    expect(state.status, SubscriptionStatus.active);
    expect(state.subscriptionExpiresAt, expiresAt);
    expect(state.phoneVerified, isTrue);
    expect(state.proVerified, isTrue);
    expect(state.toFirestoreSeedMap(), <String, dynamic>{
      'subscriptionPlan': 'ilipro',
      'subscriptionStatus': 'active',
      'subscriptionExpiresAt': expiresAt,
      'phoneVerified': true,
      'proVerified': true,
    });
  });
}
