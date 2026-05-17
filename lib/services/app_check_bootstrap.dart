import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../config/app_check_state.dart';
import '../firebase_init.dart';

Future<void> bootstrapAppCheck() async {
  appCheckActivationAttempted = false;
  appCheckActivationSucceeded = false;
  appCheckActivationError = null;
  appCheckActivationStackTrace = null;

  if (kDebugMode) {
    debugPrint(
      '[AppCheck] initializing platform=${firebaseInitPlatformLabel()}',
    );
  }

  try {
    if (kIsWeb) {
      final siteKey = kAppCheckWebRecaptchaSiteKey.trim();
      if (siteKey.isEmpty) {
        final error = StateError(
          'missing_app_check_recaptcha_site_key',
        );
        appCheckActivationAttempted = true;
        appCheckActivationSucceeded = false;
        appCheckActivationError = error;
        appCheckActivationStackTrace = StackTrace.current;
        if (kDebugMode) {
          debugPrint('[AppCheck] missing_app_check_recaptcha_site_key');
        }
        try {
          await FirebaseCrashlytics.instance.recordError(
            error,
            appCheckActivationStackTrace,
            reason: 'missing_app_check_recaptcha_site_key',
            fatal: false,
          );
        } catch (_) {}
        return;
      }

      final preview = siteKey.length > 10 ? siteKey.substring(0, 10) : siteKey;
      if (kDebugMode) debugPrint('[APPCHECK] siteKey=$preview...');
      appCheckActivationAttempted = true;
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaEnterpriseProvider(siteKey),
      );
      final token = await FirebaseAppCheck.instance
          .getToken(true)
          .timeout(const Duration(seconds: 8));
      if ((token ?? '').trim().isEmpty) {
        throw StateError('Jeton App Check vide apres activation');
      }
      appCheckActivationSucceeded = true;
      return;
    }

    appCheckActivationAttempted = true;
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
    final token = await FirebaseAppCheck.instance
        .getToken(true)
        .timeout(const Duration(seconds: 8));
    if ((token ?? '').trim().isEmpty) {
      throw StateError('Jeton App Check vide apres activation');
    }
    appCheckActivationSucceeded = true;
  } catch (error, stackTrace) {
    appCheckActivationAttempted = true;
    appCheckActivationSucceeded = false;
    appCheckActivationError = error;
    appCheckActivationStackTrace = stackTrace;
    if (kDebugMode) {
      debugPrint('[AppCheck] activation failed: $error');
    }
  }
}