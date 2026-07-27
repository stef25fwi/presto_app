import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/marketplace_human_verification_mobile.dart';

void main() {
  group('mobile human verification coverage', () {
    test('returns empty outside Android and iOS', () async {
      final token = await requestMarketplaceHumanVerificationToken(
        action: 'publish_offer',
        androidSiteKey: 'android-key',
        iosSiteKey: 'ios-key',
        webSiteKey: 'web-key',
        isAndroidOverride: false,
        isIosOverride: false,
        executor: (_, __) async => fail('executor must not run'),
      );

      expect(token, isEmpty);
    });

    test('uses the trimmed Android key and token', () async {
      String? usedKey;
      String? usedAction;
      final token = await requestMarketplaceHumanVerificationToken(
        action: 'report_listing',
        androidSiteKey: '  android-key  ',
        iosSiteKey: 'ios-key',
        webSiteKey: 'web-key',
        isAndroidOverride: true,
        isIosOverride: false,
        executor: (siteKey, action) async {
          usedKey = siteKey;
          usedAction = action;
          return '  android-token  ';
        },
      );

      expect(usedKey, 'android-key');
      expect(usedAction, 'report_listing');
      expect(token, 'android-token');
    });

    test('uses the iOS key when Android is false', () async {
      String? usedKey;
      final token = await requestMarketplaceHumanVerificationToken(
        action: 'contact_seller',
        androidSiteKey: 'android-key',
        iosSiteKey: ' ios-key ',
        webSiteKey: 'web-key',
        isAndroidOverride: false,
        isIosOverride: true,
        executor: (siteKey, _) async {
          usedKey = siteKey;
          return 'ios-token';
        },
      );

      expect(usedKey, 'ios-key');
      expect(token, 'ios-token');
    });

    test('returns empty for a blank selected site key', () async {
      final token = await requestMarketplaceHumanVerificationToken(
        action: 'publish_offer',
        androidSiteKey: '   ',
        iosSiteKey: 'ios-key',
        webSiteKey: 'web-key',
        isAndroidOverride: true,
        isIosOverride: false,
        executor: (_, __) async => fail('executor must not run'),
      );

      expect(token, isEmpty);
    });

    test('absorbs executor failures', () async {
      final token = await requestMarketplaceHumanVerificationToken(
        action: 'publish_offer',
        androidSiteKey: 'android-key',
        iosSiteKey: 'ios-key',
        webSiteKey: 'web-key',
        isAndroidOverride: true,
        isIosOverride: false,
        executor: (_, __) async => throw StateError('plugin unavailable'),
      );

      expect(token, isEmpty);
    });
  });
}
