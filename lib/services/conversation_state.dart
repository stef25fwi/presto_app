bool readConversationFlagForUser(
  Map<String, dynamic> data,
  String field,
  String userId,
) {
  final raw = data[field];
  if (raw is! Map) return false;
  return raw[userId] == true;
}

bool isConversationArchivedForUser(Map<String, dynamic> data, String userId) {
  return readConversationFlagForUser(data, 'archivedBy', userId);
}

bool isConversationDeletedForUser(Map<String, dynamic> data, String userId) {
  return readConversationFlagForUser(data, 'deletedBy', userId);
}

bool isConversationBlocked(Map<String, dynamic> data) {
  final raw = data['blockedBy'];
  if (raw is! Map) return false;
  for (final value in raw.values) {
    if (value == true) return true;
  }
  return false;
}

bool isConversationBlockedForUser(Map<String, dynamic> data, String userId) {
  return readConversationFlagForUser(data, 'blockedBy', userId);
}

bool isConversationBlockedByOtherUser(
  Map<String, dynamic> data,
  String userId,
) {
  final raw = data['blockedBy'];
  if (raw is! Map) return false;
  for (final entry in raw.entries) {
    if (entry.key.toString() == userId) continue;
    if (entry.value == true) return true;
  }
  return false;
}

bool shouldShowConversation({
  required Map<String, dynamic> data,
  required String userId,
  required bool showArchivedOnly,
}) {
  if (isConversationDeletedForUser(data, userId)) {
    return false;
  }
  final isArchived = isConversationArchivedForUser(data, userId);
  return showArchivedOnly ? isArchived : !isArchived;
}
