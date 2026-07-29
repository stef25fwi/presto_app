import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_action_placeholders.dart';

void main() {
  tearDown(resetSubscriptionActionOverrides);

  test('commercial mode override is awaited and reset deterministically', () async {
    var calls = 0;
    subscriptionCommercialModeResolverOverride = () async {
      calls += 1;
      return true;
    };

    expect(await resolveSubscriptionCommercialModeForTesting(), isTrue);
    expect(calls, 1);

    resetSubscriptionActionOverrides();
    expect(subscriptionCommercialModeResolverOverride, isNull);
  });
}
