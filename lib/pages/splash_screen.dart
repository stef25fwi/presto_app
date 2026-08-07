import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_globals.dart';
import '../app/app_runtime_config.dart';
import '../app/startup_state.dart';
import '../app/system_ui_style.dart';
import '../app_core.dart';
import '../services/initial_route_resolver.dart';
import '../services/notification_service.dart';
import 'consult_offers_page.dart' show UserPublicProfilePage;
import 'home_page.dart';
import 'messages/messages_page_v2.dart';
import 'offers/offer_details_page.dart';
import 'publish_offer_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(prestoOverlayStyleFor(kPrestoOrange));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    final isRoot =
        !kIsWeb || _normalizedWebPath().isEmpty || _normalizedWebPath() == '/';
    _scheduleNavigation(
      isRoot ? Duration.zero : const Duration(milliseconds: 120),
    );
  }

  String _normalizedWebPath() {
    final rawPath = Uri.base.path.trim();
    if (rawPath.isEmpty) return '/';
    return rawPath.endsWith('/') && rawPath.length > 1
        ? rawPath.substring(0, rawPath.length - 1)
        : rawPath;
  }

  Widget _destinationForCurrentLocation() {
    final resolution = resolveInitialRoute(kIsWeb ? Uri.base.toString() : '/');
    pendingPostAuthRoute = null;

    switch (resolution.kind) {
      case InitialRouteKind.account:
        return const HomePage(initialIndex: 4);
      case InitialRouteKind.publish:
        return const PublishOfferPage();
      case InitialRouteKind.offer:
        final target = resolution.deepLinkTarget!;
        return OfferDeepLinkPage(
          offerId: target.offerId!,
          preferMarketplace: target.preferMarketplace,
        );
      case InitialRouteKind.profile:
        return UserPublicProfilePage(
          userId: resolution.deepLinkTarget!.userId!,
        );
      case InitialRouteKind.messages:
        final target = resolution.deepLinkTarget!;
        return MessagesPageV2(
          initialConversationId: target.conversationId,
          initialDraftText: target.initialDraftText,
        );
      case InitialRouteKind.home:
        return const HomePage();
    }
  }

  void _scheduleNavigation(Duration duration) {
    _navTimer?.cancel();
    _navTimer = Timer(duration, () {
      try {
        _navigateTo(_destinationForCurrentLocation());
      } catch (_) {
        try {
          _navigateTo(const HomePage());
        } catch (_) {}
      }
      _maybePushColdStartNotificationRoute();
    });
  }

  void _maybePushColdStartNotificationRoute() {
    final route = NotificationService().consumeColdStartRoute();
    if (route == null || route.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appNavigatorKey.currentState?.pushNamed(route);
    });
  }

  void _navigateTo(Widget page) {
    if (!mounted) return;
    _navTimer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _navTimer?.cancel();
    SystemChrome.setSystemUIOverlayStyle(prestoOverlayStyleFor(kPrestoBlue));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: prestoOverlayStyleFor(kPrestoOrange),
      child: Scaffold(
        backgroundColor: kPrestoOrange,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: const Text(
                          'iliprestō',
                          style: TextStyle(
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Trouvez un prestataire\nillico presto!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 46),
                      SizedBox(
                        width: 260,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white, width: 2),
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 8,
                            ),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          onPressed: () =>
                              _navigateTo(const HomePage(initialIndex: 2)),
                          child: const Text(
                            "J'offre un job",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: 260,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 8,
                            ),
                            backgroundColor: kPrestoBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          onPressed: () =>
                              _navigateTo(const HomePage(initialIndex: 1)),
                          child: const Text(
                            'Je consulte les offres',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _SplashBuildStamp(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashBuildStamp extends StatelessWidget {
  const _SplashBuildStamp();

  @override
  Widget build(BuildContext context) {
    final shortSha = kAppBuildSha == 'local'
        ? 'local'
        : (kAppBuildSha.length > 12
            ? kAppBuildSha.substring(0, 12)
            : kAppBuildSha);
    final primaryLine = 'v$kAppVersion+$kAppBuildNumber • commit $shortSha';
    final secondaryParts = <String>[
      if (kAppBuildBranch.trim().isNotEmpty) 'branch ${kAppBuildBranch.trim()}',
      if (kAppBuildTag.trim().isNotEmpty) 'tag ${kAppBuildTag.trim()}',
      if (kAppBuildTimeUtc.trim().isNotEmpty)
        'build ${kAppBuildTimeUtc.trim()}',
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                primaryLine,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (secondaryParts.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  secondaryParts.join(' • '),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
