import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/runtime_stores.dart';
import '../app/system_ui_style.dart';
import '../app/typography_settings.dart';
import '../app_core.dart';
import '../firebase_init.dart';
import '../services/ads_consent_service.dart';
import '../services/app_check_bootstrap.dart';
import '../services/app_monitoring_service.dart';
import '../services/city_search.dart';
import '../services/cookie_consent_service.dart';
import '../services/firestore_bootstrap.dart';
import 'auth_startup.dart';
import 'background_services.dart';
import 'crash_reporting.dart';
import 'firebase_runtime_startup.dart';
import 'release_logging.dart';

Future<void> bootstrapPrestoApp(Widget app) async {
  runZonedGuarded(() async {
    silenceDebugPrintInRelease();
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

    // Google UMP requires a fresh consent-information update on each native
    // app launch. This refresh does NOT initialize Mobile Ads and does NOT
    // request an ad. The actual ad path remains double-gated by iliprestō's
    // marketing choice and UMP canRequestAds().
    if (!kIsWeb) {
      unawaited(AdsConsentService.instance.refreshPrivacyState());
    }

    await bootstrapAppCheck();

    adminWebDebugStore.recordEvent(area: 'firebase', message: 'initialized');
    await bootstrapFirestore();
    adminWebDebugStore.recordEvent(area: 'firestore', message: 'bootstrapped');

    // Remote Config (+ l'activation réseau Firestore côté natif) et l'état
    // d'authentification (persistence + retour de redirection OAuth) sont
    // deux chaînes réseau indépendantes : les lancer en parallèle plutôt
    // qu'en série évite de payer deux fois un aller-retour réseau complet
    // avant le premier rendu.
    await Future.wait([
      initializeFirebaseRuntimeServices(),
      initializeAuthState(),
    ]);
    adminWebDebugStore.recordEvent(area: 'app', message: 'runtime-ready');

    SystemChrome.setSystemUIOverlayStyle(prestoOverlayStyleFor(kPrestoBlue));
    await configureCrashReporting();

    runApp(app);
    unawaited(initializeBackgroundServices());
  }, recordBootstrapZoneError);
}
