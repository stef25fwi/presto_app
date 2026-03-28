export function readConversationParticipants(data: Record<string, unknown>): string[] {
  const result: string[] = [];
  const seen = new Set<string>();

  for (const field of ["participants", "participant_ids"] as const) {
    const raw = data[field];
    if (!Array.isArray(raw)) continue;

    for (const value of raw) {
      const participantId = String(value || "").trim();
      if (!participantId || seen.has(participantId)) continue;
      seen.add(participantId);
      result.push(participantId);
    }
  }

  return result;
}

export function buildConversationParticipantFields(participants: string[]): {
  participants: string[];
  participant_ids: string[];
} {
  const normalized = participants
    .map((value) => String(value || "").trim())
    .filter(Boolean)
    .filter((value, index, all) => all.indexOf(value) === index);

  return {
    participants: normalized,
    participant_ids: normalized,
  };
}