import 'campaign_attribution_service.dart';

class AppDeepLinkTarget {
  static const String messagesRouteName = '/messages';
  static const String messagesV2RouteName = '/messages-2';

  final String routeName;
  final String? conversationId;
  final String? initialDraftText;
  final String? offerId;
  final String? userId;
  final bool preferMarketplace;

  const AppDeepLinkTarget._({
    required this.routeName,
    this.conversationId,
    this.initialDraftText,
    this.offerId,
    this.userId,
    this.preferMarketplace = false,
  });

  const AppDeepLinkTarget.profile(String userId)
      : this._(
          routeName: '/profile',
          userId: userId,
        );

  const AppDeepLinkTarget.messages({String? initialDraftText})
      : this._(
          routeName: messagesRouteName,
          initialDraftText: initialDraftText,
        );

  const AppDeepLinkTarget.messagesV2({String? initialDraftText})
      : this._(
          routeName: messagesV2RouteName,
          initialDraftText: initialDraftText,
        );

  const AppDeepLinkTarget.messageThread(
    String conversationId, {
    String? initialDraftText,
  }) : this._(
          routeName: messagesRouteName,
          conversationId: conversationId,
          initialDraftText: initialDraftText,
        );

  const AppDeepLinkTarget.messageThreadV2(
    String conversationId, {
    String? initialDraftText,
  }) : this._(
          routeName: messagesV2RouteName,
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
  return _buildMessageRoute(
    routeName: AppDeepLinkTarget.messagesRouteName,
    conversationId: conversationId,
    initialDraftText: initialDraftText,
  );
}

String buildMessagesV2Route({
  String? conversationId,
  String? initialDraftText,
}) {
  return _buildMessageRoute(
    routeName: AppDeepLinkTarget.messagesV2RouteName,
    conversationId: conversationId,
    initialDraftText: initialDraftText,
  );
}

String _buildMessageRoute({
  required String routeName,
  String? conversationId,
  String? initialDraftText,
}) {
  final normalizedConversationId = (conversationId ?? '').trim();
  final normalizedDraftText = (initialDraftText ?? '').trim();

  final path = normalizedConversationId.isEmpty
      ? routeName
      : '$routeName/${Uri.encodeComponent(normalizedConversationId)}';

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

  CampaignAttributionService.instance.observeRoute(name);
  final uri = effectiveCampaignUri(name);
  if (uri == null) return null;

  final segments = uri.pathSegments
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  final initialDraftText = (uri.queryParameters['draft'] ?? '').trim();
  final normalizedDraftText =
      initialDraftText.isEmpty ? null : initialDraftText;

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

  if (segments.length == 1 && segments.first == 'messages-2') {
    return AppDeepLinkTarget.messagesV2(initialDraftText: normalizedDraftText);
  }

  if (segments.length == 2 &&
      segments.first == 'messages-2' &&
      segments[1].isNotEmpty) {
    return AppDeepLinkTarget.messageThreadV2(
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

  if (segments.length == 2 &&
      (segments.first == 'profile' || segments.first == 'profil') &&
      segments[1].isNotEmpty) {
    return AppDeepLinkTarget.profile(
      Uri.decodeComponent(segments[1]),
    );
  }

  return null;
}
