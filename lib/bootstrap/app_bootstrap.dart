import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_globals.dart';
import '../app/app_runtime_config.dart';
import '../app/runtime_stores.dart';
import '../app/startup_state.dart';
import '../app/system_ui_style.dart';
import '../app/theme.dart';
import '../app/typography_settings.dart';
import '../app_core.dart';
import '../debug_auth.dart';
import '../firebase_init.dart';
import '../services/app_check_bootstrap.dart';
import '../services/app_monitoring_service.dart';
import '../services/city_search.dart';
import '../services/cookie_consent_service.dart';
import '../services/firestore_bootstrap.dart';
import '../services/notification_service.dart';
import '../services/post_auth_navigation_intent_service.dart';

Future<void> _initBackgroundServices() async {
  try {
    await NotificationService().initialize(navigatorKey: appNavigatorKey);
    adminWebDebugStore.recordEvent(
      area: 'notifications',
      message: 'initialized',
    );
  } catch (error) {
    adminWebDebugStore.recordError(
      'notifications',
      error,
      message: 'init-failed',
    );
    if (kDebugMode) debugPrint('[Notifications] init error: $error');
  }
}

Future<void> bootstrapPrestoApp(Widget app) async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    AppMonitoringService.instance.configureGlobalErrorHandling();

    adminWebDebugStore.recordEvent(
      area: 'app',
      message: 'startup',
      detail: 'platform=${kIsWeb ? 'web' : defaultTargetPlatform.name}',
    );

    unawaited(CitySearch.instance.ensureLoaded());
    unawaited(typographySettings.load());

    await ensureFirebaseInitialized(source: 'main');
    unawaited(CookieConsentService.instance.load());
    await bootstrapAppCheck();

    adminWebDebugStore.recordEvent(area: 'firebase', message: 'initialized');
    await bootstrapFirestore();
    adminWebDebugStore.recordEvent(area: 'firestore', message: 'bootstrapped');

    _logFirebaseDiagnostics();
    await _enableFirestoreNetwork();
    await _initializeRemoteConfig();
    await _initializeAuthState();

    SystemChrome.setSystemUIOverlayStyle(prestoOverlayStyleFor(kPrestoBlue));
    await _configureCrashReporting();

    runApp(app);
    unawaited(_initBackgroundServices());
  }, (error, stack) {
    adminWebDebugStore.recordError(
      'zone',
      error,
      stackTrace: stack,
      message: 'runZonedGuarded',
    );
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

void _logFirebaseDiagnostics() {
  if (!kDebugMode) return;
  debugPrint('=== Firebase Initialization ===');
  debugPrint('[FirebaseInit] ready platform=${firebaseInitPlatformLabel()}');
  debugPrint('✓ Auth instance: ${FirebaseAuth.instance.runtimeType}');
  debugPrint('✓ Firestore instance: ${FirebaseFirestore.instance.runtimeType}');
  debugPrint('[Firestore] initialization ready');
  if (kIsWeb) {
    debugPrint('✓ Platform: Web');
    debugPrint('  - Google Sign-In: Popup + Redirect fallback');
  } else {
    debugPrint('✓ Platform: ${defaultTargetPlatform.toString().split('.').last}');
  }
  debugPrint('');
}

Future<void> _enableFirestoreNetwork() async {
  if (kIsWeb) {
    if (kDebugMode) {
      debugPrint('✓ Firestore Web: Persistence (IndexedDB if available)');
    }
    return;
  }
  try {
    await FirebaseFirestore.instance.enableNetwork();
    if (kDebugMode) debugPrint('✓ Firestore persistence: Enabled');
  } catch (error) {
    if (kDebugMode) debugPrint('⚠️ Firestore persistence error: $error');
  }
}

Future<void> _initializeRemoteConfig() async {
  await PrestoRemoteConfig.init();
  if (kDebugMode) {
    debugPrint('[RC] audio_pipeline=${PrestoRemoteConfig.audioPipeline}');
  }
  adminWebDebugStore.recordEvent(
    area: 'remote-config',
    message: 'initialized',
    detail: 'audio_pipeline=${PrestoRemoteConfig.audioPipeline}',
  );
}

Future<void> _initializeAuthState() async {
  try {
    final auth = FirebaseAuth.instance;
    if (kDebugMode) DebugAuth.installAuthStateLogs();

    if (kIsWeb) {
      try {
        await auth.setPersistence(Persistence.LOCAL);
      } catch (error) {
        if (kDebugMode) debugPrint('[Auth] setPersistence failed: $error');
      }

      try {
        pendingRedirectAuthResult = await auth
            .getRedirectResult()
            .timeout(const Duration(seconds: 10));
        if (kDebugMode) {
          debugPrint(
            '[Auth] getRedirectResult: user='
            '${pendingRedirectAuthResult?.user?.uid} '
            'provider=${pendingRedirectAuthResult?.credential?.providerId}',
          );
        }
      } catch (error) {
        pendingRedirectAuthError = error;
        if (kDebugMode) debugPrint('[Auth] getRedirectResult error: $error');
      }

      final shouldRestorePostAuthRoute =
          pendingRedirectAuthResult?.user != null || pendingRedirectAuthError != null;
      if (shouldRestorePostAuthRoute) {
        try {
          pendingPostAuthRoute =
              await PostAuthNavigationIntentService.takePendingRoute();
          if (kDebugMode && pendingPostAuthRoute != null) {
            debugPrint('[Auth] pending post-auth route=$pendingPostAuthRoute');
          }
        } catch (error) {
          if (kDebugMode) debugPrint('[Auth] takePendingRoute failed: $error');
        }
      }
    }

    if (auth.currentUser != null) {
      if (kDebugMode) {
        debugPrint('[Auth] User already signed in: ${auth.currentUser!.uid}');
      }
      SessionState.userId = auth.currentUser!.uid;
    } else {
      if (kDebugMode) debugPrint('[Auth] No user signed in at startup (OK)');
      SessionState.userId = null;
    }

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      SessionState.userId = user?.uid;
      adminWebDebugStore.updateAuth(user);
      if (kDebugMode) {
        debugPrint('[Auth] global state changed: ${user?.uid ?? "null"}');
      }
    });
  } catch (error) {
    adminWebDebugStore.recordError(
      'auth',
      error,
      message: 'startup-check-failed',
    );
    if (kDebugMode) debugPrint('[Auth] check failed: $error');
  }
}

Future<void> _configureCrashReporting() async {
  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    previousFlutterOnError?.call(details);
    adminWebDebugStore.recordError(
      'flutter',
      details.exception,
      stackTrace: details.stack,
      message: details.library ?? 'flutter-error',
    );
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    adminWebDebugStore.recordError(
      'platform',
      error,
      stackTrace: stack,
      message: 'platform-dispatcher',
    );
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };

  if (!kIsWeb) {
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);
  }
}
