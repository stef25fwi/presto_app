String? conversationIdFromMessageDocumentPath(String path) {
  final segments = path
      .split('/')
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);

  for (var index = 0; index + 3 < segments.length; index += 1) {
    if (segments[index] != 'conversations') continue;
    if (segments[index + 2] != 'messages') continue;

    final conversationId = segments[index + 1];
    if (conversationId.isNotEmpty) {
      return conversationId;
    }
  }

  return null;
}

List<String> mergeUniqueConversationIds(Iterable<String?> rawIds) {
  final result = <String>[];
  final seen = <String>{};

  for (final rawId in rawIds) {
    final conversationId = (rawId ?? '').trim();
    if (conversationId.isEmpty || !seen.add(conversationId)) continue;
    result.add(conversationId);
  }

  return result;
}
