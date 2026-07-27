import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/cookie_consent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CookieConsentService.instance.resetForTesting();
  });

  test('rejects an unknown serialized choice', () {
    final restored = CookieConsentState.fromJson(<String, dynamic>{
      'choice': 'unsupported-choice',
      'analyticsAllowed': true,
      'marketingAllowed': true,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });

    expect(restored, isNull);
  });

  test('restores a valid v2 consent state', () async {
    final updatedAt = DateTime.now().toUtc().subtract(const Duration(days: 1));
    SharedPreferences.setMockInitialValues(<String, Object>{
      'cookie_consent_v2': jsonEncode(<String, dynamic>{
        'choice': CookieConsentChoice.accepted.name,
        'analyticsAllowed': true,
        'marketingAllowed': true,
        'updatedAt': updatedAt.toIso8601String(),
        'schemaVersion': 2,
      }),
    });

    await CookieConsentService.instance.load();

    final state = CookieConsentService.instance.state;
    expect(state, isNotNull);
    expect(state!.choice, CookieConsentChoice.accepted);
    expect(state.analyticsAllowed, isTrue);
    expect(state.marketingAllowed, isTrue);
    expect(state.updatedAt, updatedAt);
    expect(CookieConsentService.instance.shouldShowBanner, isFalse);
  });

  test('removes an expired legacy consent state', () async {
    final expiredAt = DateTime.now()
        .toUtc()
        .subtract(CookieConsentService.retentionDuration)
        .subtract(const Duration(days: 1));
    SharedPreferences.setMockInitialValues(<String, Object>{
      'cookie_consent_v1': jsonEncode(<String, dynamic>{
        'choice': CookieConsentChoice.refused.name,
        'analyticsAllowed': false,
        'marketingAllowed': false,
        'updatedAt': expiredAt.toIso8601String(),
      }),
    });

    await CookieConsentService.instance.load();

    expect(CookieConsentService.instance.state, isNull);
    expect(CookieConsentService.instance.shouldShowBanner, isTrue);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('cookie_consent_v1'), isFalse);
    expect(preferences.containsKey('cookie_consent_v2'), isFalse);
  });

  test('normalizes unknown and removes the legacy key when saving', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'cookie_consent_v1': 'legacy-value',
    });

    await CookieConsentService.instance.savePreferences(
      analyticsAllowed: true,
      marketingAllowed: false,
      choice: CookieConsentChoice.unknown,
    );

    final state = CookieConsentService.instance.state;
    expect(state, isNotNull);
    expect(state!.choice, CookieConsentChoice.customized);
    expect(state.analyticsAllowed, isTrue);
    expect(state.marketingAllowed, isFalse);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('cookie_consent_v1'), isFalse);
    expect(preferences.containsKey('cookie_consent_v2'), isTrue);
  });
}
