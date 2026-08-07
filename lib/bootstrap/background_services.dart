import 'package:flutter/foundation.dart';

import '../app/app_globals.dart';
import '../app/runtime_stores.dart';
import '../services/notification_service.dart';

Future<void> initializeBackgroundServices() async {
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
