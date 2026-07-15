import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_return_history.dart';

void main() {
  test('prepareSubscriptionReturnHistory completes safely off web', () {
    expect(prepareSubscriptionReturnHistory, returnsNormally);
  });
}
