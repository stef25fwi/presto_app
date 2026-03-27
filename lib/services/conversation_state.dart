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

bool isConversationBlocked(Map<String, dynamic> data) {
  final raw = data['blockedBy'];
  if (raw is Map) {
    for (final value in raw.values) {
      if (value == true) return true;
    }
  }

  final status = (data['status'] ?? '').toString().trim().toLowerCase();
  return status == 'closed';
}

bool isConversationBlockedForUser(Map<String, dynamic> data, String userId) {
  return readConversationFlagForUser(data, 'blockedBy', userId);
}

bool shouldShowConversation({
  required Map<String, dynamic> data,
  required String userId,
  required bool showArchivedOnly,
}) {
  final isArchived = isConversationArchivedForUser(data, userId);
  return showArchivedOnly ? isArchived : !isArchived;
}