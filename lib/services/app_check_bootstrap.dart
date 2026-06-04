import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../config/app_check_state.dart';
import '../firebase_init.dart';

Future<void>? _appCheckTokenRefreshInFlight;

Future<void> refreshAppCheckToken({
  required String reason,
  bool forceRefresh = false,
}) {
  final inFlight = _appCheckTokenRefreshInFlight;
  if (inFlight != null) return inFlight;

  final refresh = () async {
    if (!appCheckActivationAttempted) {
      throw StateError('app_check_not_activated_for_token_refresh:$reason');
    }

    try {
      final token = await FirebaseAppCheck.instance
          .getToken(forceRefresh)
          .timeout(const Duration(seconds: 8));
      if ((token ?? '').trim().isEmpty) {
        throw StateError('Jeton App Check vide pendant refresh: $reason');
      }
      appCheckActivationSucceeded = true;
      appCheckActivationError = null;
      appCheckActivationStackTrace = null;
      appCheckLastTokenRefreshAt = DateTime.now();
      appCheckLastTokenRefreshError = null;
      if (kDebugMode) {
        debugPrint('[AppCheck] token refresh ok reason=$reason');
      }
    } catch (error, stackTrace) {
      appCheckActivationSucceeded = false;
      appCheckActivationError = error;
      appCheckActivationStackTrace = stackTrace;
      appCheckLastTokenRefreshError = error;
      if (kDebugMode) {
        debugPrint('[AppCheck] token refresh failed reason=$reason error=$error');
      }
      rethrow;
    } finally {
      _appCheckTokenRefreshInFlight = null;
    }
  }();

  _appCheckTokenRefreshInFlight = refresh;
  return refresh;
}

Future<void> bootstrapAppCheck() async {
  appCheckActivationAttempted = false;
  appCheckActivationSucceeded = false;
  appCheckActivationError = null;
  appCheckActivationStackTrace = null;
  appCheckLastTokenRefreshAt = null;
  appCheckLastTokenRefreshError = null;

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
      if (kDebugMode) {
        debugPrint(
          '[APPCHECK] provider=$kAppCheckWebRecaptchaProviderLabel '
          'siteKey=$preview...',
        );
      }
      appCheckActivationAttempted = true;
      await activateAppCheckWeb(siteKey);
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      await refreshAppCheckToken(reason: 'bootstrap-web', forceRefresh: true);
      return;
    }

    appCheckActivationAttempted = true;
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    await refreshAppCheckToken(reason: 'bootstrap-native', forceRefresh: true);
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