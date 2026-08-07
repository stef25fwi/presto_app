import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_globals.dart';
import 'app_routes.dart';
import 'presto_app_chrome.dart';
import 'runtime_stores.dart';
import 'theme.dart';
import '../core/connectivity/connectivity_status.dart';
import '../core/localization/locale_controller.dart';
import '../l10n/app_localizations.dart';
import '../services/app_check_bootstrap.dart';
import '../services/notification_service.dart';
import '../widgets/admin_web_debug_panel.dart';
import '../widgets/app_shell_widgets.dart';

class PrestoApp extends StatefulWidget {
  const PrestoApp({super.key});

  @override
  State<PrestoApp> createState() => _PrestoAppState();
}

class _PrestoAppState extends State<PrestoApp> with WidgetsBindingObserver {
  static const AppRoutes _routes = AppRoutes();

  bool _navigatorReadySignaled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ConnectivityStatus.instance.start();
    unawaited(LocaleController.instance.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    adminWebDebugStore.recordEvent(area: 'lifecycle', message: 'resumed');
    unawaited(
      refreshAppCheckToken(reason: 'app-resumed').catchError((Object error) {
        if (kDebugMode) {
          debugPrint('[AppCheck] resume refresh skipped: $error');
        }
      }),
    );
  }

  void _signalNavigatorReady() {
    if (_navigatorReadySignaled) return;
    _navigatorReadySignaled = true;
    NotificationService().markNavigatorReady();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) => _buildMaterialApp(),
    );
  }

  Widget _buildMaterialApp() {
    return MaterialApp(
      title: 'iliprestō',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (deviceLocale, supportedLocales) =>
          LocaleController.instance.resolveDeviceLocale(deviceLocale),
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _signalNavigatorReady();
        });
        return PrestoAppChrome(
          child: AdminWebDebugPanel(
            child: PrestoResponsiveFrame(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      onGenerateInitialRoutes: _routes.generateInitialRoutes,
      onGenerateRoute: _routes.generateRoute,
      routes: _routes.namedRoutes(),
      theme: buildPrestoTheme(),
      home: _routes.buildInitialHome(),
    );
  }
}
