import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import 'firebase_runtime_startup.dart';

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

    await initializeFirebaseRuntimeServices();
    await initializeAuthState();

    SystemChrome.setSystemUIOverlayStyle(prestoOverlayStyleFor(kPrestoBlue));
    await configureCrashReporting();

    runApp(app);
    unawaited(initializeBackgroundServices());
  }, recordBootstrapZoneError);
}
