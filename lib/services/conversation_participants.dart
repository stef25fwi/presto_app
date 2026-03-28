const conversationParticipantQueryFieldAliases = <String>[
  'participants',
  'participant_ids',
  'participantIds',
  'userIds',
  'memberIds',
];

const conversationParticipantFieldAliases = <String>[
  ...conversationParticipantQueryFieldAliases,
];

const conversationParticipantMapAliases = <String>[
  'participantNames',
  'participant_names',
  'unreadCount',
  'unread_count',
  'lastReadAt',
  'last_read_at',
  'archivedBy',
  'blockedBy',
];

List<String> readConversationParticipants(Map<String, dynamic> data) {
  final result = <String>[];
  final seen = <String>{};

  void addParticipant(dynamic value) {
    final participantId = value.toString().trim();
    if (participantId.isEmpty || !seen.add(participantId)) return;
    result.add(participantId);
  }

  for (final field in conversationParticipantFieldAliases) {
    final raw = data[field];
    if (raw is! List) continue;

    for (final entry in raw) {
      addParticipant(entry);
    }
  }

  for (final field in conversationParticipantMapAliases) {
    final raw = data[field];
    if (raw is! Map) continue;

    for (final key in raw.keys) {
      addParticipant(key);
    }
  }

  result.sort();
  return result;
}

bool conversationIncludesUser(Map<String, dynamic> data, String userId) {
  final normalizedUserId = userId.trim();
  if (normalizedUserId.isEmpty) return false;
  return readConversationParticipants(data).contains(normalizedUserId);
}