import 'package:flutter/foundation.dart';

import 'marketplace_human_verification_stub.dart'
    if (dart.library.js_interop) 'marketplace_human_verification_web.dart'
    if (dart.library.io) 'marketplace_human_verification_mobile.dart' as impl;

enum MarketplaceHumanVerificationAction {
  listingSubmit,
  listingReport,
  chatFirstMessage,
  messageReport,
}

extension MarketplaceHumanVerificationActionValue
    on MarketplaceHumanVerificationAction {
  String get value => switch (this) {
        MarketplaceHumanVerificationAction.listingSubmit => 'listing_submit',
        MarketplaceHumanVerificationAction.listingReport => 'listing_report',
        MarketplaceHumanVerificationAction.chatFirstMessage => 'message_create',
        MarketplaceHumanVerificationAction.messageReport => 'message_report',
      };
}

class MarketplaceHumanVerification {
  const MarketplaceHumanVerification();

  static const String _androidSiteKey = String.fromEnvironment(
    'MARKETPLACE_RECAPTCHA_ANDROID_SITE_KEY',
    defaultValue: '',
  );
  static const String _iosSiteKey = String.fromEnvironment(
    'MARKETPLACE_RECAPTCHA_IOS_SITE_KEY',
    defaultValue: '',
  );
  static const String _webSiteKey = String.fromEnvironment(
    'APPCHECK_RECAPTCHA_SITE_KEY',
    defaultValue: '',
  );

  static String get _effectiveWebSiteKey {
    return _webSiteKey.trim();
  }

  Future<String> obtainToken(
    MarketplaceHumanVerificationAction action,
  ) {
    final webSiteKey = _effectiveWebSiteKey;

    if (kDebugMode) {
      debugPrint(
        '[Marketplace reCAPTCHA] init '
        'action=${action.value} '
        'hasWebSiteKey=${webSiteKey.isNotEmpty}',
      );
    }

    return impl.requestMarketplaceHumanVerificationToken(
      action: action.value,
      androidSiteKey: _androidSiteKey,
      iosSiteKey: _iosSiteKey,
      webSiteKey: webSiteKey,
    );
  }
}
