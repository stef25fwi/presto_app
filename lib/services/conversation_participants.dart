List<String> readConversationParticipants(Map<String, dynamic> data) {
  final result = <String>[];
  final seen = <String>{};

  for (final field in const ['participants', 'participant_ids']) {
    final raw = data[field];
    if (raw is! List) continue;

    for (final entry in raw) {
      final participantId = entry.toString().trim();
      if (participantId.isEmpty || !seen.add(participantId)) continue;
      result.add(participantId);
    }
  }

  return result;
}