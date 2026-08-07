import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../app/runtime_stores.dart';

Future<void> configureCrashReporting() async {
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

void recordBootstrapZoneError(Object error, StackTrace stack) {
  adminWebDebugStore.recordError(
    'zone',
    error,
    stackTrace: stack,
    message: 'runZonedGuarded',
  );
  if (!kIsWeb) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  }
}
