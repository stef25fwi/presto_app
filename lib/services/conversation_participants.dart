const conversationPrimaryParticipantField = 'participantIds';

// Champ unique interrogé côté client (.where(field, arrayContains: uid)).
// Toutes les conversations écrites par les Cloud Functions portent
// `participantIds` ; le backfill garantit ce champ sur les documents legacy.
// N'ajouter un alias ici que s'il est AUSSI autorisé dans firestore.rules
// (allow list), sinon la requête échoue en permission-denied.
const conversationParticipantQueryFieldAliases = <String>[
  conversationPrimaryParticipantField,
];

// Côté lecture (parsing d'un document déjà chargé) on reste tolérant à tous
// les anciens alias pour ne jamais perdre les participants d'un document legacy.
const conversationParticipantFieldAliases = <String>[
  'participantIds',
  'participants',
  'participant_ids',
  'userIds',
  'memberIds',
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

List<String> readConversationParticipants(
  Map<String, dynamic> data, {
  String? conversationId,
}) {
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

  for (final participantId
      in readConversationParticipantIdsFromCanonicalId(conversationId ?? '')) {
    addParticipant(participantId);
  }

  result.sort();
  return result;
}

List<String> readConversationParticipantIdsFromCanonicalId(
    String conversationId) {
  final normalizedConversationId = conversationId.trim();
  if (!normalizedConversationId.startsWith('offer_')) {
    return const <String>[];
  }

  final parts = normalizedConversationId
      .substring('offer_'.length)
      .split('__')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  if (parts.length < 3) {
    return const <String>[];
  }

  final participantIds = parts.sublist(1).toList(growable: false)..sort();
  return participantIds;
}

bool conversationIncludesUser(
  Map<String, dynamic> data,
  String userId, {
  String? conversationId,
}) {
  final normalizedUserId = userId.trim();
  if (normalizedUserId.isEmpty) return false;
  return readConversationParticipants(
    data,
    conversationId: conversationId,
  ).contains(normalizedUserId);
}
