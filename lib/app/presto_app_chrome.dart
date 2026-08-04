import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/connectivity/connectivity_status.dart';
import '../pages/home_page.dart';
import '../pages/public_prelaunch_page.dart';
import '../platform/public_prelaunch_shell.dart';
import '../services/public_landing_config_service.dart';
import '../widgets/cookie_consent_banner.dart';
import '../widgets/offline_banner.dart';
import 'app_globals.dart';
import 'typography_settings.dart';

@visibleForTesting
bool resetNavigatorToHomeAfterPublicLandingAccess(
  GlobalKey<NavigatorState> navigatorKey, {
  WidgetBuilder? homeBuilder,
}) {
  final navigator = navigatorKey.currentState;
  if (navigator == null) return false;

  unawaited(
    navigator.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/'),
        builder: homeBuilder ?? (_) => const HomePage(),
      ),
      (route) => false,
    ),
  );
  return true;
}

/// Habillage commun à toutes les pages : réglages typographiques de
/// l'utilisateur (police, graisse, échelle) puis les bandeaux superposés —
/// consentement cookies en bas, état hors-ligne en haut.
///
/// Sur les domaines publics uniquement, ce composant peut remplacer
/// temporairement toute l'application par la page de pré-lancement pilotée
/// depuis Firebase Remote Config. Les canaux Hosting de prévisualisation et les
/// routes d'administration/authentification restent accessibles pour continuer
/// les travaux pendant la période de préparation.
class PrestoAppChrome extends StatefulWidget {
  final Widget child;

  const PrestoAppChrome({super.key, required this.child});

  @override
  State<PrestoAppChrome> createState() => _PrestoAppChromeState();
}

class _PrestoAppChromeState extends State<PrestoAppChrome>
    with WidgetsBindingObserver {
  static bool _temporaryDeveloperAccessGranted = false;

  final PublicLandingConfigService _publicLanding =
      PublicLandingConfigService.instance;

  Timer? _refreshTimer;
  bool _publicLandingBypassed = _temporaryDeveloperAccessGranted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _publicLanding.addListener(_handlePublicLandingChanged);
    unawaited(_publicLanding.initialize());

    if (kIsWeb) {
      _refreshTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => unawaited(_publicLanding.refresh()),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb && state == AppLifecycleState.resumed) {
      unawaited(_publicLanding.refresh());
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _publicLanding.removeListener(_handlePublicLandingChanged);
    super.dispose();
  }

  void _handlePublicLandingChanged() {
    if (mounted) setState(() {});
  }

  void _openApplicationHome({int remainingAttempts = 3}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (resetNavigatorToHomeAfterPublicLandingAccess(appNavigatorKey)) return;
      if (remainingAttempts <= 1) return;
      _openApplicationHome(remainingAttempts: remainingAttempts - 1);
    });
  }

  void _revealApplicationAfterHomePaint() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) revealApplicationAfterPublicPrelaunch();
      });
    });
  }

  void _grantTemporaryDeveloperAccess() {
    if (!mounted || _publicLandingBypassed) return;
    _temporaryDeveloperAccessGranted = true;
    setState(() => _publicLandingBypassed = true);
    _openApplicationHome();
    _revealApplicationAfterHomePaint();
  }

  @override
  Widget build(BuildContext context) {
    if (!_publicLandingBypassed && _publicLanding.shouldShowFor(Uri.base)) {
      return PublicPrelaunchPage(
        config: _publicLanding,
        onDeveloperAccessGranted: _grantTemporaryDeveloperAccess,
      );
    }

    return ListenableBuilder(
      listenable: typographySettings,
      builder: (ctx, _) {
        final base = Theme.of(ctx);
        final delta = typographySettings.fontWeightDelta;
        final withFamily =
            base.textTheme.apply(fontFamily: typographySettings.fontFamily);
        final withWeight = shiftTextThemeWeight(withFamily, delta);
        final primaryWithFamily = base.primaryTextTheme
            .apply(fontFamily: typographySettings.fontFamily);
        final primaryWithWeight =
            shiftTextThemeWeight(primaryWithFamily, delta);
        return Theme(
          data: base.copyWith(
            textTheme: withWeight,
            primaryTextTheme: primaryWithWeight,
            appBarTheme: base.appBarTheme.copyWith(
              titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
                fontFamily: typographySettings.fontFamily,
              ),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(ctx).copyWith(
              textScaler: TextScaler.linear(typographySettings.scale),
            ),
            child: Stack(
              children: [
                widget.child,
                const CookieConsentBanner(),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ListenableBuilder(
                    listenable: ConnectivityStatus.instance,
                    builder: (_, __) => OfflineBanner(
                      isVisible: !ConnectivityStatus.instance.isOnline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
