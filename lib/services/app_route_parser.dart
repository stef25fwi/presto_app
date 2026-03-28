class AppDeepLinkTarget {
  final String routeName;
  final String? conversationId;
  final String? initialDraftText;
  final String? offerId;
  final bool preferMarketplace;

  const AppDeepLinkTarget._({
    required this.routeName,
    this.conversationId,
    this.initialDraftText,
    this.offerId,
    this.preferMarketplace = false,
  });

  const AppDeepLinkTarget.messages({String? initialDraftText})
      : this._(
          routeName: '/messages',
          initialDraftText: initialDraftText,
        );

  const AppDeepLinkTarget.messageThread(
    String conversationId, {
    String? initialDraftText,
  })
      : this._(
          routeName: '/messages',
          conversationId: conversationId,
          initialDraftText: initialDraftText,
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

String buildMessagesRoute({
  String? conversationId,
  String? initialDraftText,
}) {
  final normalizedConversationId = (conversationId ?? '').trim();
  final normalizedDraftText = (initialDraftText ?? '').trim();

  final path = normalizedConversationId.isEmpty
      ? '/messages'
      : '/messages/${Uri.encodeComponent(normalizedConversationId)}';

  if (normalizedDraftText.isEmpty) {
    return path;
  }

  return Uri(
    path: path,
    queryParameters: <String, String>{
      'draft': normalizedDraftText,
    },
  ).toString();
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
  final initialDraftText = (uri.queryParameters['draft'] ?? '').trim();
  final normalizedDraftText = initialDraftText.isEmpty ? null : initialDraftText;

  if (segments.length == 1 && segments.first == 'messages') {
    return AppDeepLinkTarget.messages(initialDraftText: normalizedDraftText);
  }

  if (segments.length == 2 &&
      segments.first == 'messages' &&
      segments[1].isNotEmpty) {
    return AppDeepLinkTarget.messageThread(
      Uri.decodeComponent(segments[1]),
      initialDraftText: normalizedDraftText,
    );
  }

  if (segments.length == 2 &&
      segments.first == 'chat' &&
      segments[1].isNotEmpty) {
    return AppDeepLinkTarget.messageThread(
      Uri.decodeComponent(segments[1]),
      initialDraftText: normalizedDraftText,
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