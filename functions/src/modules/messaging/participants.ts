export const CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES = [
  "participants",
  "participant_ids",
  "participantIds",
  "userIds",
  "memberIds",
] as const;

export const CONVERSATION_PARTICIPANT_FIELD_ALIASES = [
  ...CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES,
] as const;

export const CONVERSATION_PARTICIPANT_MAP_ALIASES = [
  "participantNames",
  "participant_names",
  "unreadCount",
  "unread_count",
  "lastReadAt",
  "last_read_at",
  "archivedBy",
  "blockedBy",
] as const;

export function readConversationParticipants(data: Record<string, unknown>): string[] {
  const result: string[] = [];
  const seen = new Set<string>();

  const appendParticipant = (value: unknown): void => {
    const normalized = String(value ?? "").trim();
    if (!normalized || seen.has(normalized)) return;
    seen.add(normalized);
    result.push(normalized);
  };

  for (const field of CONVERSATION_PARTICIPANT_FIELD_ALIASES) {
    const raw = data[field];
    if (!Array.isArray(raw)) continue;

    for (const value of raw) {
      appendParticipant(value);
    }
  }

  for (const field of CONVERSATION_PARTICIPANT_MAP_ALIASES) {
    const raw = data[field];
    if (!raw || typeof raw !== "object") continue;

    for (const key of Object.keys(raw as Record<string, unknown>)) {
      appendParticipant(key);
    }
  }

  result.sort();
  return result;
}

export function buildConversationParticipantFields(participants: string[]): {
  participants: string[];
  participant_ids: string[];
  participantIds: string[];
} {
  const normalized = participants
    .map((value) => String(value || "").trim())
    .filter(Boolean)
    .filter((value, index, all) => all.indexOf(value) === index);

  return {
    participants: normalized,
    participantIds: normalized,
    participant_ids: normalized,
  };
}