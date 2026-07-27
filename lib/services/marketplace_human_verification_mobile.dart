import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha_action.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha_client.dart';

typedef MarketplaceMobileTokenExecutor = Future<String> Function(
  String siteKey,
  String action,
);

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

Future<String> _executeMarketplaceMobileToken(
  String siteKey,
  String action,
) async {
  final client = await _fetchClient(siteKey);
  return client.execute(
    RecaptchaAction.custom(action),
    timeout: 10000,
  );
}

Future<String> requestMarketplaceHumanVerificationToken({
  required String action,
  required String androidSiteKey,
  required String iosSiteKey,
  required String webSiteKey,
  bool? isAndroidOverride,
  bool? isIosOverride,
  MarketplaceMobileTokenExecutor? executor,
}) async {
  final isAndroid = isAndroidOverride ?? Platform.isAndroid;
  final isIos = isIosOverride ?? Platform.isIOS;
  if (!isAndroid && !isIos) {
    return '';
  }

  final siteKey = isAndroid ? androidSiteKey : iosSiteKey;
  if (siteKey.trim().isEmpty) {
    return '';
  }

  try {
    final execute = executor ?? _executeMarketplaceMobileToken;
    final token = await execute(siteKey.trim(), action);
    return token.trim();
  } catch (error) {
    debugPrint('[Marketplace reCAPTCHA] mobile execution failed: $error');
    return '';
  }
}
