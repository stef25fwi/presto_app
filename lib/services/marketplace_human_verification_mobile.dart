import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha_action.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha_client.dart';

RecaptchaClient? _client;
Future<RecaptchaClient>? _clientFuture;
String _siteKeyInUse = '';

Future<RecaptchaClient> _fetchClient(String siteKey) {
  if (_client != null && _siteKeyInUse == siteKey) {
    return Future<RecaptchaClient>.value(_client!);
  }
  _clientFuture ??= Recaptcha.fetchClient(siteKey).then((client) {
    _client = client;
    _siteKeyInUse = siteKey;
    return client;
  }).whenComplete(() {
    _clientFuture = null;
  });
  return _clientFuture!;
}

Future<String> requestMarketplaceHumanVerificationToken({
  required String action,
  required String androidSiteKey,
  required String iosSiteKey,
  required String webSiteKey,
}) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return '';
  }

  final siteKey = Platform.isAndroid ? androidSiteKey : iosSiteKey;
  if (siteKey.trim().isEmpty) {
    return '';
  }

  try {
    final client = await _fetchClient(siteKey.trim());
    final token = await client.execute(
      RecaptchaAction.custom(action),
      timeout: 10000,
    );
    return token.trim();
  } catch (error) {
    debugPrint('[Marketplace reCAPTCHA] mobile execution failed: $error');
    return '';
  }
}