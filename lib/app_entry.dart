import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app_globals.dart';
import 'app/app_runtime_config.dart';
import 'app/presto_app_chrome.dart';
import 'app/runtime_stores.dart';
import 'app/secondary_named_routes.dart';
import 'app/startup_state.dart';
import 'app/theme.dart';
import 'bootstrap/app_bootstrap.dart';
import 'core/connectivity/connectivity_status.dart';
import 'core/localization/locale_controller.dart';
import 'dev/page_capture_catalog_page.dart';
import 'l10n/app_localizations.dart';
import 'pages/account/account_security_page.dart';
import 'pages/account/change_email_page.dart';
import 'pages/account/change_password_page.dart';
import 'pages/account/delete_account_page.dart';
import 'pages/admin_space_page.dart';
import 'pages/auth/forgot_password_page.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/register_page.dart';
import 'pages/auth/reset_password_success_page.dart';
import 'pages/auth/verify_email_page.dart';
import 'pages/consult_offers_page.dart' show UserPublicProfilePage;
import 'pages/home_page.dart';
import 'pages/legal/account_deletion_info_page.dart';
import 'pages/legal_info_page.dart';
import 'pages/messages/messages_page_v2.dart';
import 'pages/publish_offer_page.dart';
import 'pages/splash_screen.dart';
import 'pages/toolbox_je_me_lance_page.dart';
import 'services/app_check_bootstrap.dart';
import 'services/app_route_parser.dart';
import 'services/notification_service.dart';
import 'widgets/admin_web_debug_panel.dart';
import 'widgets/app_shell_widgets.dart';

export 'app/app_runtime_config.dart';
export 'app/runtime_stores.dart';
export 'app/startup_state.dart';
export 'app/system_ui_style.dart';
export 'pages/publish_offer_page.dart' show PublishOfferPage;
export 'pages/splash_screen.dart' show SplashScreen;
export 'services/offer_details_mapper.dart' show buildOfferDetailsOffer;
export 'services/presto_monitoring.dart' show PrestoMonitoring;
export 'services/region_resolver.dart' show inferRegionFromPostalCode;
export 'widgets/app_shell_widgets.dart' show CardShell, PrestoResponsiveFrame;
export 'widgets/audio_pipeline_badge.dart' show AudioPipelineBadge;

Future<void> main() => bootstrapPrestoApp(const PrestoApp());

class PrestoApp extends StatefulWidget {
  const PrestoApp({super.key});

  @override
  State<PrestoApp> createState() => _PrestoAppState();
}

class _PrestoAppState extends State<PrestoApp> with WidgetsBindingObserver {
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

  Widget _buildInitialHome() {
    final initialWebPath =
        Uri.base.path.trim().isEmpty ? '/' : Uri.base.path.trim();
    if (initialWebPath.isEmpty ||
        initialWebPath == '/' ||
        initialWebPath == '/login') {
      pendingPostAuthRoute = null;
    }

    if (kIsWeb) {
      final rawPath = Uri.base.path.trim();
      final normalizedPath = rawPath.endsWith('/') && rawPath.length > 1
          ? rawPath.substring(0, rawPath.length - 1)
          : rawPath;
      if (!kReleaseMode && normalizedPath == '/page-catalog') {
        return const PageCaptureCatalogPage();
      }
      if (!kReleaseMode && normalizedPath == '/toolbox-fonctionnaire-test') {
        return const ToolboxJeMeLancePage();
      }
    }

    if (!kReleaseMode && kDebugStartPage == 'toolbox_fonctionnaire') {
      return const ToolboxJeMeLancePage();
    }
    return const SplashScreen();
  }

  void _signalNavigatorReady() {
    if (_navigatorReadySignaled) return;
    _navigatorReadySignaled = true;
    NotificationService().markNavigatorReady();
  }

  List<Route<dynamic>> _onGenerateInitialRoutes(String initialRouteName) {
    final parsed = Uri.tryParse(initialRouteName);
    final rawPath = (parsed?.path ?? initialRouteName).trim();
    final normalizedPath = rawPath.isEmpty
        ? '/'
        : rawPath.endsWith('/') && rawPath.length > 1
            ? rawPath.substring(0, rawPath.length - 1)
            : rawPath;

    if (normalizedPath == LoginPage.routeName) {
      return <Route<dynamic>>[
        MaterialPageRoute(
          settings: const RouteSettings(name: LoginPage.routeName),
          builder: (_) => const LoginPage(),
        ),
      ];
    }

    final legalTab = LegalInfoPage.tabForRoute(normalizedPath);
    if (legalTab != null) {
      return <Route<dynamic>>[
        MaterialPageRoute(
          settings: RouteSettings(name: normalizedPath),
          builder: (_) => LegalInfoPage(initialTab: legalTab),
        ),
      ];
    }

    if (normalizedPath == AccountDeletionInfoPage.routeName) {
      return <Route<dynamic>>[
        MaterialPageRoute(
          settings: const RouteSettings(name: AccountDeletionInfoPage.routeName),
          builder: (_) => const AccountDeletionInfoPage(),
        ),
      ];
    }

    if (normalizedPath == '/account') {
      pendingPostAuthRoute = null;
      return <Route<dynamic>>[
        MaterialPageRoute(
          settings: const RouteSettings(name: '/account'),
          builder: (_) => const HomePage(initialIndex: 4),
        ),
      ];
    }

    return <Route<dynamic>>[
      MaterialPageRoute(
        settings: const RouteSettings(name: '/'),
        builder: (_) => _buildInitialHome(),
      ),
    ];
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final parsedRoute = Uri.tryParse(settings.name ?? '');
    if (!kReleaseMode && parsedRoute?.path == '/page-catalog') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const PageCaptureCatalogPage(),
      );
    }
    if (!kReleaseMode && parsedRoute?.path == '/toolbox-fonctionnaire-test') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const ToolboxJeMeLancePage(),
      );
    }

    final target = parseAppDeepLink(settings.name);
    if (target == null) return null;

    if (target.offerId != null) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => OfferDeepLinkPage(
          offerId: target.offerId!,
          preferMarketplace: target.preferMarketplace,
        ),
      );
    }
    if (target.userId != null && target.routeName == '/profile') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => UserPublicProfilePage(userId: target.userId!),
      );
    }
    if (target.routeName == AppDeepLinkTarget.messagesRouteName ||
        target.routeName == AppDeepLinkTarget.messagesV2RouteName) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => MessagesPageV2(
          initialConversationId: target.conversationId,
          initialDraftText: target.initialDraftText,
        ),
      );
    }

    return MaterialPageRoute(
      settings: settings,
      builder: (_) => HomePage(
        initialIndex: 3,
        initialMessagesConversationId: target.conversationId,
        initialMessagesDraftText: target.initialDraftText,
      ),
    );
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
      onGenerateInitialRoutes: _onGenerateInitialRoutes,
      onGenerateRoute: _onGenerateRoute,
      routes: {
        LoginPage.routeName: (_) => const LoginPage(),
        RegisterPage.routeName: (_) => const RegisterPage(),
        ForgotPasswordPage.routeName: (_) => const ForgotPasswordPage(),
        VerifyEmailPage.routeName: (_) => const VerifyEmailPage(),
        ResetPasswordSuccessPage.routeName: (_) =>
            const ResetPasswordSuccessPage(email: ''),
        AccountSecurityPage.routeName: (_) => const AccountSecurityPage(),
        ChangeEmailPage.routeName: (_) => const ChangeEmailPage(),
        ChangePasswordPage.routeName: (_) => const ChangePasswordPage(),
        DeleteAccountPage.routeName: (_) => const DeleteAccountPage(),
        LegalInfoPage.legalNoticesRouteName: (_) => const LegalInfoPage(),
        LegalInfoPage.privacyRouteName: (_) =>
            const LegalInfoPage(initialTab: 1),
        LegalInfoPage.termsRouteName: (_) => const LegalInfoPage(initialTab: 2),
        AccountDeletionInfoPage.routeName: (_) =>
            const AccountDeletionInfoPage(),
        '/publish': (_) => const PublishOfferPage(),
        '/messages': (_) => const MessagesPageV2(),
        '/messages-2': (_) => const MessagesPageV2(),
        '/account': (_) => const HomePage(initialIndex: 4),
        '/admin': (_) => const AdminSpacePage(),
        if (!kReleaseMode)
          '/page-catalog': (_) => const PageCaptureCatalogPage(),
        if (!kReleaseMode)
          '/toolbox-fonctionnaire-test': (_) => const ToolboxJeMeLancePage(),
        ...buildSecondaryNamedRoutes(),
      },
      theme: buildPrestoTheme(),
      home: _buildInitialHome(),
    );
  }
}
