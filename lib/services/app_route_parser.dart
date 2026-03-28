class AppDeepLinkTarget {
  final String routeName;
  final String? conversationId;
  final String? offerId;
  final bool preferMarketplace;

  const AppDeepLinkTarget._({
    required this.routeName,
    this.conversationId,
    this.offerId,
    this.preferMarketplace = false,
  });

  const AppDeepLinkTarget.messages() : this._(routeName: '/messages');

  const AppDeepLinkTarget.messageThread(String conversationId)
      : this._(
          routeName: '/messages',
          conversationId: conversationId,
        );

  const AppDeepLinkTarget.offerDetail(String offerId)
      : this._(
          routeName: '/offers',
          offerId: offerId,
        );

  const AppDeepLinkTarget.listingDetail(String offerId)
      : this._(
          routeName: '/listings',
          offerId: offerId,
          preferMarketplace: true,
        );
}

AppDeepLinkTarget? parseAppDeepLink(String? rawName) {
  final name = (rawName ?? '').trim();
  if (name.isEmpty) return null;

  Uri uri;
  try {
    uri = Uri.parse(name);
  } catch (_) {
    return null;
  }

  if (uri.pathSegments.isEmpty && uri.fragment.isNotEmpty) {
    final fragment = uri.fragment.startsWith('/')
        ? uri.fragment
        : '/${uri.fragment}';
    try {
      uri = Uri.parse(fragment);
    } catch (_) {
      return null;
    }
  }

  final segments = uri.pathSegments
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);

  if (segments.length == 1 && segments.first == 'messages') {
    return const AppDeepLinkTarget.messages();
  }

  if (segments.length == 2 &&
      segments.first == 'messages' &&
      segments[1].isNotEmpty) {
    return AppDeepLinkTarget.messageThread(
      Uri.decodeComponent(segments[1]),
    );
  }

  if (segments.length == 2 &&
      segments.first == 'chat' &&
      segments[1].isNotEmpty) {
    return AppDeepLinkTarget.messageThread(
      Uri.decodeComponent(segments[1]),
    );
  }

  if (segments.length == 2 &&
      segments.first == 'offers' &&
      segments[1].isNotEmpty) {
    return AppDeepLinkTarget.offerDetail(
      Uri.decodeComponent(segments[1]),
    );
  }

  if (segments.length == 2 &&
      segments.first == 'listings' &&
      segments[1].isNotEmpty) {
    return AppDeepLinkTarget.listingDetail(
      Uri.decodeComponent(segments[1]),
    );
  }

  return null;
}