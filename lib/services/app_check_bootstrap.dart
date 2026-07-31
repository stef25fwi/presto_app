import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../config/app_check_state.dart';
import '../firebase_init.dart';
import 'admin_web_debug_store.dart';

/// Borne l'activation App Check : sur mobile web, le chargement de
/// reCAPTCHA Enterprise peut ne jamais se résoudre (réseau lent, stockage
/// restreint juste après une redirection OAuth cross-site, bloqueur de
/// script). `activate()` n'a pas de timeout interne ; sans cette borne,
/// `bootstrapAppCheck()` bloquerait indéfiniment `runApp()` dans main.dart
/// et l'utilisateur resterait coincé sur le fond orange de démarrage.
const Duration _appCheckActivationTimeout = Duration(seconds: 10);

const String _webRecaptchaEnterpriseSiteKeyFromDefine = String.fromEnvironment(
  'RECAPTCHA_ENTERPRISE_SITE_KEY',
);

// Site key publique reCAPTCHA Enterprise pour ilipresto.fr.
// Fallback volontaire pour éviter siteKeySet=false si le --dart-define est oublié.
const String _webRecaptchaEnterpriseSiteKeyFallback =
    '6Lc0DuIsAAAAAI7JFa1B6EY1OpCs43kPMDqBFJhC';

String get _effectiveWebRecaptchaEnterpriseSiteKey {
  final fromDefine = _webRecaptchaEnterpriseSiteKeyFromDefine.trim();
  if (fromDefine.isNotEmpty) return fromDefine;
  return _webRecaptchaEnterpriseSiteKeyFallback.trim();
}

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
          .timeout(const Duration(seconds: 15));
      if ((token ?? '').trim().isEmpty) {
        throw StateError('Jeton App Check vide pendant refresh: $reason');
      }
      appCheckActivationSucceeded = true;
      appCheckActivationError = null;
      appCheckActivationStackTrace = null;
      appCheckLastTokenRefreshAt = DateTime.now();
      appCheckLastTokenRefreshError = null;
      AdminWebDebugStore.instance.recordEvent(
        area: 'appcheck',
        message: 'token-refresh-ok',
        detail: 'reason=$reason forceRefresh=$forceRefresh',
      );
      if (kDebugMode) {
        debugPrint('[AppCheck] token refresh ok reason=$reason');
      }
    } catch (error, stackTrace) {
      appCheckActivationSucceeded = false;
      appCheckActivationError = error;
      appCheckActivationStackTrace = stackTrace;
      appCheckLastTokenRefreshError = error;
      AdminWebDebugStore.instance.recordError(
        'appcheck',
        error,
        stackTrace: stackTrace,
        message: 'token-refresh-failed',
      );
      if (kDebugMode) {
        debugPrint(
            '[AppCheck] token refresh failed reason=$reason error=$error');
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
  AdminWebDebugStore.instance.recordEvent(
    area: 'appcheck',
    message: 'bootstrap-start',
    detail: 'platform=${firebaseInitPlatformLabel()}',
  );

  try {
    if (kIsWeb) {
      final siteKey = _effectiveWebRecaptchaEnterpriseSiteKey.trim();
      final host = currentAppCheckWebHost();
      final hostClass = appCheckWebHostClass(host);
      if (siteKey.isEmpty) {
        final error = StateError(
          'missing_app_check_recaptcha_site_key',
        );
        appCheckActivationAttempted = true;
        appCheckActivationSucceeded = false;
        appCheckActivationError = error;
        appCheckActivationStackTrace = StackTrace.current;
        AdminWebDebugStore.instance.recordError(
          'appcheck',
          error,
          stackTrace: appCheckActivationStackTrace,
          message: 'missing-site-key',
        );
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
          'siteKey=$preview... host=$host hostClass=$hostClass',
        );
        final hostHint = appCheckWebHostHint();
        if (hostHint.isNotEmpty) {
          debugPrint('[APPCHECK] host-warning:$hostHint');
        }
      }
      AdminWebDebugStore.instance.recordEvent(
        area: 'appcheck',
        message: 'activate-web',
        detail:
            'host=$host hostClass=$hostClass provider=$kAppCheckWebRecaptchaProviderLabel',
      );
      appCheckActivationAttempted = true;
      await FirebaseAppCheck.instance
          .activate(
            webProvider: ReCaptchaEnterpriseProvider(
                _effectiveWebRecaptchaEnterpriseSiteKey),
            androidProvider: kDebugMode
                ? AndroidProvider.debug
                : AndroidProvider.playIntegrity,
            appleProvider:
                kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
          )
          .timeout(_appCheckActivationTimeout);
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      await refreshAppCheckToken(reason: 'bootstrap-web', forceRefresh: true);
      return;
    }

    appCheckActivationAttempted = true;
    AdminWebDebugStore.instance.recordEvent(
      area: 'appcheck',
      message: 'activate-native',
      detail: 'platform=${firebaseInitPlatformLabel()}',
    );
    await FirebaseAppCheck.instance
        .activate(
          androidProvider:
              kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
          appleProvider:
              kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
        )
        .timeout(_appCheckActivationTimeout);
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    await refreshAppCheckToken(reason: 'bootstrap-native', forceRefresh: true);
  } catch (error, stackTrace) {
    appCheckActivationAttempted = true;
    appCheckActivationSucceeded = false;
    appCheckActivationError = error;
    appCheckActivationStackTrace = stackTrace;
    AdminWebDebugStore.instance.recordError(
      'appcheck',
      error,
      stackTrace: stackTrace,
      message: 'activation-failed',
    );
    if (kDebugMode) {
      debugPrint('[AppCheck] activation failed: $error');
    }
  }
}
