import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_runtime_config.dart';
import '../app/runtime_stores.dart';
import '../app/system_ui_style.dart';
import '../app/typography_settings.dart';
import '../app_core.dart';
import '../firebase_init.dart';
import '../services/app_check_bootstrap.dart';
import '../services/app_monitoring_service.dart';
import '../services/city_search.dart';
import '../services/cookie_consent_service.dart';
import '../services/firestore_bootstrap.dart';
import 'auth_startup.dart';
import 'background_services.dart';
import 'crash_reporting.dart';

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
    await initializeAuthState();

    SystemChrome.setSystemUIOverlayStyle(prestoOverlayStyleFor(kPrestoBlue));
    await configureCrashReporting();

    runApp(app);
    unawaited(initializeBackgroundServices());
  }, recordBootstrapZoneError);
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
