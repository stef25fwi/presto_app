import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/subscriptions/subscription_return_history.dart';
import 'package:presto_app/features/subscriptions/subscription_return_history_policy.dart';

void main() {
  test(
    'prepareSubscriptionReturnHistory reste sans effet hors Web',
    () {
      expect(prepareSubscriptionReturnHistory, returnsNormally);
      expect(prepareSubscriptionReturnHistory, returnsNormally);
    },
  );

  group('subscriptionReturnPathToPush', () {
    test('ne prépare pas deux fois l entrée Stripe exacte', () {
      final current = Uri.parse(
        'https://ilipresto.fr/account?section=subscriptions&from=stripe',
      );

      expect(subscriptionReturnPathToPush(current), isNull);
    });

    test('prépare le retour quand le marqueur Stripe manque', () {
      final current = Uri.parse(
        'https://ilipresto.fr/account?section=subscriptions',
      );

      expect(subscriptionReturnPathToPush(current), subscriptionReturnPath);
    });

    test('prépare le retour quand la source n est pas Stripe', () {
      final current = Uri.parse(
        'https://ilipresto.fr/account?section=subscriptions&from=profile',
      );

      expect(subscriptionReturnPathToPush(current), subscriptionReturnPath);
    });

    test('prépare le retour depuis une autre page', () {
      final current = Uri.parse(
        'https://ilipresto.fr/offers?section=subscriptions&from=stripe',
      );

      expect(subscriptionReturnPathToPush(current), subscriptionReturnPath);
    });

    test('reste idempotent avec des paramètres supplémentaires', () {
      final current = Uri.parse(
        'https://ilipresto.fr/account?section=subscriptions&from=stripe&plan=pro',
      );

      expect(subscriptionReturnPathToPush(current), isNull);
    });
  });
}
