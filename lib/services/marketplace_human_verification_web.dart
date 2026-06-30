// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('prestoMarketplaceRecaptcha')
external _MarketplaceRecaptchaBridge? get _prestoMarketplaceRecaptcha;

@JS()
@staticInterop
class _MarketplaceRecaptchaBridge {}

extension _MarketplaceRecaptchaBridgeExtension on _MarketplaceRecaptchaBridge {
  external JSPromise<JSString?> execute(JSString siteKey, JSString action);
}

Future<String> requestMarketplaceHumanVerificationToken({
  required String action,
  required String androidSiteKey,
  required String iosSiteKey,
  required String webSiteKey,
}) async {
  final siteKey = webSiteKey.trim();
  if (siteKey.isEmpty) {
    return '';
  }

  try {
    final bridge = _prestoMarketplaceRecaptcha;
    if (bridge == null) {
      debugPrint('[Marketplace reCAPTCHA] web bridge unavailable');
      return '';
    }

    // Un timeout est indispensable : la promesse JS peut ne jamais se regler
    // (script reCAPTCHA bloque sans onerror, grecaptcha.ready muet, execute
    // sans callback) -> sans cela le bouton "Je publie" tourne a l'infini.
    final token =
        await bridge.execute(siteKey.toJS, action.toJS).toDart.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        debugPrint('[Marketplace reCAPTCHA] web execution timed out');
        return null;
      },
    );
    return token?.toDart.trim() ?? '';
  } catch (error) {
    debugPrint('[Marketplace reCAPTCHA] web execution failed: $error');
    return '';
  }
}
