import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/cookie_consent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('couvre la sérialisation et tout le cycle de consentement', () async {
    final timestamp = DateTime.utc(2026, 7, 21, 4, 30);
    final state = CookieConsentState(
      choice: CookieConsentChoice.customized,
      analyticsAllowed: true,
      marketingAllowed: false,
      updatedAt: timestamp,
    );

    expect(state.hasChoice, isTrue);
    expect(state.toJson(), <String, dynamic>{
      'choice': 'customized',
      'analyticsAllowed': true,
      'marketingAllowed': false,
      'updatedAt': timestamp.toIso8601String(),
      'schemaVersion': 2,
    });
    expect(CookieConsentState.fromJson(null), isNull);
    expect(
      CookieConsentState.fromJson(<String, dynamic>{'choice': 'unknown'}),
      isNull,
    );
    final restored = CookieConsentState.fromJson(<String, dynamic>{
      'choice': 'accepted',
      'analyticsAllowed': true,
      'marketingAllowed': true,
      'updatedAt': timestamp.toIso8601String(),
    });
    expect(restored?.choice, CookieConsentChoice.accepted);
    expect(restored?.analyticsAllowed, isTrue);
    expect(restored?.marketingAllowed, isTrue);
    expect(restored?.updatedAt, timestamp);
    expect(
      CookieConsentState.fromJson(<String, dynamic>{
        'choice': 'refused',
        'updatedAt': 'date-invalide',
      })?.updatedAt,
      isNull,
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'cookie_consent_v1': jsonEncode(<String, dynamic>{
        'choice': 'accepted',
        'analyticsAllowed': true,
        'marketingAllowed': false,
        'updatedAt': timestamp.toIso8601String(),
      }),
    });

    final service = CookieConsentService.instance;
    var notifications = 0;
    service.addListener(() => notifications += 1);

    expect(service.isLoaded, isFalse);
    expect(service.state, isNull);
    expect(service.hasChoice, isFalse);
    expect(service.shouldShowBanner, isTrue);
    expect(service.canUseAnalytics, isFalse);
    expect(service.canUseMarketing, isFalse);
    expect(service.choiceUpdatedAt, isNull);

    await service.load();
    expect(service.isLoaded, isTrue);
    expect(service.state?.choice, CookieConsentChoice.accepted);
    expect(service.hasChoice, isTrue);
    expect(service.shouldShowBanner, isFalse);
    expect(service.canUseAnalytics, isTrue);
    expect(service.canUseMarketing, isFalse);
    expect(service.choiceUpdatedAt, timestamp);
    expect(notifications, 1);

    await service.load();
    expect(notifications, 1);

    await service.refuseAll();
    expect(service.state?.choice, CookieConsentChoice.refused);
    expect(service.canUseAnalytics, isFalse);
    expect(service.canUseMarketing, isFalse);

    await service.acceptAll();
    expect(service.state?.choice, CookieConsentChoice.accepted);
    expect(service.canUseAnalytics, isTrue);
    expect(service.canUseMarketing, isTrue);

    await service.savePreferences(
      analyticsAllowed: true,
      marketingAllowed: false,
      choice: CookieConsentChoice.unknown,
    );
    expect(service.state?.choice, CookieConsentChoice.customized);
    expect(service.state?.updatedAt?.isUtc, isTrue);

    final prefs = await SharedPreferences.getInstance();
    final persisted = jsonDecode(prefs.getString('cookie_consent_v2')!);
    expect(persisted['choice'], 'customized');
    expect(persisted['analyticsAllowed'], isTrue);
    expect(persisted['marketingAllowed'], isFalse);
    expect(persisted['schemaVersion'], 2);
    expect(notifications, 4);

    service.removeListener(() => notifications += 1);
  });
}
