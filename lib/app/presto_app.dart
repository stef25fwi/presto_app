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
import '../pages/legal_info_page.dart';
import '../pages/public_prelaunch_page.dart';
import '../platform/public_prelaunch_shell.dart';
import '../services/app_check_bootstrap.dart';
import '../services/notification_service.dart';
import '../services/public_landing_config_service.dart';
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
      builder: (context, _) => _PublicPrelaunchEntryGate(
        applicationBuilder: _buildMaterialApp,
      ),
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

enum PublicPrelaunchEntryMode {
  application,
  landing,
  legalNotices,
  terms,
}

@visibleForTesting
PublicPrelaunchEntryMode resolvePublicPrelaunchEntryMode(
  Uri uri, {
  required bool enabled,
  required bool hasDeveloperAccess,
  bool isWeb = kIsWeb,
}) {
  if (!isWeb || !enabled || hasDeveloperAccess) {
    return PublicPrelaunchEntryMode.application;
  }

  const publicHosts = <String>{
    'ilipresto.fr',
    'www.ilipresto.fr',
    'ilipresto.web.app',
    'ilipresto.firebaseapp.com',
    'presto-app-74abe.web.app',
    'presto-app-74abe.firebaseapp.com',
  };
  if (!publicHosts.contains(uri.host.trim().toLowerCase())) {
    return PublicPrelaunchEntryMode.application;
  }

  var path = uri.path.trim();
  if (path.isEmpty) path = '/';
  if (!path.startsWith('/')) path = '/$path';
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }

  if (path == LegalInfoPage.legalNoticesRouteName) {
    return PublicPrelaunchEntryMode.legalNotices;
  }
  if (path == LegalInfoPage.termsRouteName) {
    return PublicPrelaunchEntryMode.terms;
  }

  return PublicPrelaunchEntryMode.landing;
}

class _PublicPrelaunchEntryGate extends StatefulWidget {
  const _PublicPrelaunchEntryGate({required this.applicationBuilder});

  final Widget Function() applicationBuilder;

  @override
  State<_PublicPrelaunchEntryGate> createState() =>
      _PublicPrelaunchEntryGateState();
}

class _PublicPrelaunchEntryGateState extends State<_PublicPrelaunchEntryGate> {
  final PublicLandingConfigService _publicLanding =
      PublicLandingConfigService.instance;

  bool _temporaryDeveloperAccessGranted = false;

  @override
  void initState() {
    super.initState();
    _publicLanding.addListener(_handleConfigChanged);
    unawaited(_publicLanding.initialize());
  }

  @override
  void dispose() {
    _publicLanding.removeListener(_handleConfigChanged);
    super.dispose();
  }

  void _handleConfigChanged() {
    if (mounted) setState(() {});
  }

  void _grantDeveloperAccess() {
    if (_temporaryDeveloperAccessGranted) return;
    _temporaryDeveloperAccessGranted = true;
    revealApplicationAfterPublicPrelaunch();
    if (mounted) setState(() {});
  }

  MaterialApp _legalShell({required int initialTab}) {
    return MaterialApp(
      title: 'iliprestō',
      debugShowCheckedModeBanner: false,
      theme: buildPrestoTheme(),
      home: LegalInfoPage(
        initialTab: initialTab,
        restrictToPrelaunchLegalTabs: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = resolvePublicPrelaunchEntryMode(
      Uri.base,
      enabled: _publicLanding.enabled,
      hasDeveloperAccess:
          _temporaryDeveloperAccessGranted || hasPublicPrelaunchAccess(),
    );

    switch (mode) {
      case PublicPrelaunchEntryMode.application:
        return widget.applicationBuilder();
      case PublicPrelaunchEntryMode.legalNotices:
        return _legalShell(initialTab: 0);
      case PublicPrelaunchEntryMode.terms:
        return _legalShell(initialTab: 2);
      case PublicPrelaunchEntryMode.landing:
        return MaterialApp(
          title: 'iliprestō',
          debugShowCheckedModeBanner: false,
          theme: buildPrestoTheme(),
          home: PublicPrelaunchPage(
            config: _publicLanding,
            onDeveloperAccessGranted: _grantDeveloperAccess,
          ),
        );
    }
  }
}
