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
  // La site key reCAPTCHA est publique (embarquée dans le HTML/JS côté
  // navigateur par conception). On la fournit en valeur par défaut pour que
  // le build web dispose toujours d'une clé même si le pipeline de build
  // n'injecte pas le --dart-define : sans clé, aucun jeton ne peut être
  // produit et la publication d'annonce reste bloquée.
  static const String _webSiteKey = String.fromEnvironment(
    'MARKETPLACE_RECAPTCHA_WEB_SITE_KEY',
    defaultValue: '6Lc0DuIsAAAAAI7JFa1B6EY1OpCs43kPMDqBFJhC',
  );
  static const String _legacyWebSiteKey = String.fromEnvironment(
    'APPCHECK_RECAPTCHA_SITE_KEY',
    defaultValue: '',
  );

  Future<String> obtainToken(
    MarketplaceHumanVerificationAction action,
  ) {
    return impl.requestMarketplaceHumanVerificationToken(
      action: action.value,
      androidSiteKey: _androidSiteKey,
      iosSiteKey: _iosSiteKey,
      webSiteKey: _webSiteKey.isNotEmpty ? _webSiteKey : _legacyWebSiteKey,
    );
  }
}
