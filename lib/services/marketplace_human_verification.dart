import 'marketplace_human_verification_stub.dart'
    if (dart.library.js_interop) 'marketplace_human_verification_web.dart'
    if (dart.library.io) 'marketplace_human_verification_mobile.dart' as impl;

enum MarketplaceHumanVerificationAction {
  listingSubmit,
  listingReport,
  chatFirstMessage,
}

extension MarketplaceHumanVerificationActionValue
    on MarketplaceHumanVerificationAction {
  String get value => switch (this) {
        MarketplaceHumanVerificationAction.listingSubmit => 'listing_submit',
        MarketplaceHumanVerificationAction.listingReport => 'listing_report',
        MarketplaceHumanVerificationAction.chatFirstMessage => 'message_create',
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
    'MARKETPLACE_RECAPTCHA_WEB_SITE_KEY',
    defaultValue: '',
  );

  Future<String> obtainToken(
    MarketplaceHumanVerificationAction action,
  ) {
    return impl.requestMarketplaceHumanVerificationToken(
      action: action.value,
      androidSiteKey: _androidSiteKey,
      iosSiteKey: _iosSiteKey,
      webSiteKey: _webSiteKey,
    );
  }
}
