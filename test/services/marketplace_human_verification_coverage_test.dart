import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/marketplace_human_verification.dart';

void main() {
  test('expose les trois valeurs d action attendues', () {
    expect(
      MarketplaceHumanVerificationAction.values.map((value) => value.value),
      <String>['listing_submit', 'listing_report', 'message_create'],
    );
  });

  test('retourne un jeton vide sécurisé sur une plateforme non mobile', () async {
    const verification = MarketplaceHumanVerification();

    for (final action in MarketplaceHumanVerificationAction.values) {
      expect(await verification.obtainToken(action), isEmpty);
    }
  });
}
