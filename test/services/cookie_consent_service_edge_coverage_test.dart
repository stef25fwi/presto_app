import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/cookie_consent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load tolère une préférence JSON invalide puis normalise unknown', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'cookie_consent_v1': '{json-invalide',
    });

    final service = CookieConsentService.instance;
    var notifications = 0;
    void listener() => notifications += 1;
    service.addListener(listener);

    await service.load();

    expect(service.isLoaded, isTrue);
    expect(service.state, isNull);
    expect(service.shouldShowBanner, isTrue);
    expect(notifications, 1);

    await service.savePreferences(
      analyticsAllowed: false,
      marketingAllowed: true,
      choice: CookieConsentChoice.unknown,
    );

    expect(service.state?.choice, CookieConsentChoice.customized);
    expect(service.canUseAnalytics, isFalse);
    expect(service.canUseMarketing, isTrue);
    expect(service.choiceUpdatedAt?.isUtc, isTrue);
    expect(notifications, 2);

    service.removeListener(listener);
  });

  test('fromJson gère timestamp vide et valeurs booléennes strictes', () {
    final state = CookieConsentState.fromJson(<String, dynamic>{
      'choice': 'customized',
      'analyticsAllowed': 1,
      'marketingAllowed': 'true',
      'updatedAt': '',
    });

    expect(state, isNotNull);
    expect(state!.choice, CookieConsentChoice.customized);
    expect(state.analyticsAllowed, isFalse);
    expect(state.marketingAllowed, isFalse);
    expect(state.updatedAt, isNull);
    expect(state.hasChoice, isTrue);
  });
}
