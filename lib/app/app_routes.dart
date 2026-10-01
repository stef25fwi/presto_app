import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_runtime_config.dart';
import 'secondary_named_routes.dart';
import 'startup_state.dart';
import '../dev/page_capture_catalog_page.dart';
import '../pages/account/account_security_page.dart';
import '../pages/account/change_email_page.dart';
import '../pages/account/change_password_page.dart';
import '../pages/account/delete_account_page.dart';
import '../pages/account/mes_avis_page.dart';
import '../pages/admin_space_page.dart';
import '../pages/auth/forgot_password_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/register_page.dart';
import '../pages/auth/reset_password_success_page.dart';
import '../pages/auth/verify_email_page.dart';
import '../pages/consult_offers_page.dart' show UserPublicProfilePage;
import '../pages/home_page.dart';
import '../pages/legal/account_deletion_info_page.dart';
import '../pages/legal_info_page.dart';
import '../pages/messages/messages_page_v2.dart';
import '../pages/publish_offer_page.dart';
import '../pages/splash_screen.dart';
import '../pages/toolbox_je_me_lance_page.dart';
import '../services/app_route_parser.dart';

/// Centralise la construction des routes et des destinations de démarrage.
///
/// Ce composant ne possède aucun état Flutter : il traduit uniquement les
/// chemins entrants en widgets/routes. La gestion du cycle de vie reste dans
/// [PrestoApp].
class AppRoutes {
  const AppRoutes();

  Widget buildInitialHome() {
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

  List<Route<dynamic>> generateInitialRoutes(String initialRouteName) {
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
          settings: const RouteSettings(
            name: AccountDeletionInfoPage.routeName,
          ),
          builder: (_) => const AccountDeletionInfoPage(),
        ),
      ];
    }

    if (normalizedPath == MesAvisPage.routeName) {
      return <Route<dynamic>>[
        MaterialPageRoute(
          settings: const RouteSettings(name: MesAvisPage.routeName),
          builder: (_) => const MesAvisPage(),
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
        builder: (_) => buildInitialHome(),
      ),
    ];
  }

  Route<dynamic>? generateRoute(RouteSettings settings) {
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

  Map<String, WidgetBuilder> namedRoutes() => <String, WidgetBuilder>{
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
        MesAvisPage.routeName: (_) => const MesAvisPage(),
        LegalInfoPage.legalNoticesRouteName: (_) => const LegalInfoPage(),
        LegalInfoPage.privacyRouteName: (_) =>
            const LegalInfoPage(initialTab: 1),
        LegalInfoPage.termsRouteName: (_) =>
            const LegalInfoPage(initialTab: 2),
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
          '/toolbox-fonctionnaire-test': (_) =>
              const ToolboxJeMeLancePage(),
        ...buildSecondaryNamedRoutes(),
      };
}
