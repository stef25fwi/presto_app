import 'app_route_parser.dart';
import 'campaign_attribution_service.dart';

enum InitialRouteKind {
  home,
  account,
  publish,
  offer,
  profile,
  messages,
}

class InitialRouteResolution {
  const InitialRouteResolution._({
    required this.kind,
    required this.normalizedPath,
    this.deepLinkTarget,
  });

  final InitialRouteKind kind;
  final String normalizedPath;
  final AppDeepLinkTarget? deepLinkTarget;

  static InitialRouteResolution home({String normalizedPath = '/'}) =>
      InitialRouteResolution._(
        kind: InitialRouteKind.home,
        normalizedPath: normalizedPath,
      );

  static InitialRouteResolution direct({
    required InitialRouteKind kind,
    required String normalizedPath,
  }) =>
      InitialRouteResolution._(
        kind: kind,
        normalizedPath: normalizedPath,
      );

  static InitialRouteResolution deepLink({
    required InitialRouteKind kind,
    required String normalizedPath,
    required AppDeepLinkTarget target,
  }) =>
      InitialRouteResolution._(
        kind: kind,
        normalizedPath: normalizedPath,
        deepLinkTarget: target,
      );
}

String normalizeInitialRoutePath(String? rawLocation) {
  final effective = effectiveCampaignUri(rawLocation);
  final raw = (effective?.path ?? rawLocation ?? '').trim();
  if (raw.isEmpty) return '/';
  if (raw == '/') return '/';
  return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
}

InitialRouteResolution resolveInitialRoute(String? rawLocation) {
  CampaignAttributionService.instance.observeRoute(rawLocation);
  final normalizedPath = normalizeInitialRoutePath(rawLocation);

  switch (normalizedPath) {
    case '/':
      return InitialRouteResolution.home();
    case '/account':
      return InitialRouteResolution.direct(
        kind: InitialRouteKind.account,
        normalizedPath: normalizedPath,
      );
    case '/publish':
      return InitialRouteResolution.direct(
        kind: InitialRouteKind.publish,
        normalizedPath: normalizedPath,
      );
  }

  final target = parseAppDeepLink(rawLocation);
  if (target == null) {
    return InitialRouteResolution.home(normalizedPath: normalizedPath);
  }

  if (target.offerId != null) {
    return InitialRouteResolution.deepLink(
      kind: InitialRouteKind.offer,
      normalizedPath: normalizedPath,
      target: target,
    );
  }

  if (target.userId != null && target.routeName == '/profile') {
    return InitialRouteResolution.deepLink(
      kind: InitialRouteKind.profile,
      normalizedPath: normalizedPath,
      target: target,
    );
  }

  if (target.routeName == AppDeepLinkTarget.messagesRouteName ||
      target.routeName == AppDeepLinkTarget.messagesV2RouteName) {
    return InitialRouteResolution.deepLink(
      kind: InitialRouteKind.messages,
      normalizedPath: normalizedPath,
      target: target,
    );
  }

  return InitialRouteResolution.home(normalizedPath: normalizedPath);
}
