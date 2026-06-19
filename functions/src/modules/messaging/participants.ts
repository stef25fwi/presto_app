export const CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES = [
  "participantIds",
  "participants",
  "participant_ids",
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

function normalizeString(value: unknown): string {
  return String(value ?? "").trim();
}

export function readConversationParticipantIdsFromCanonicalId(
  conversationId: string,
): string[] {
  const normalizedConversationId = normalizeString(conversationId);
  if (!normalizedConversationId.startsWith("offer_")) {
    return [];
  }

  const parts = normalizedConversationId
    .slice("offer_".length)
    .split("__")
    .map((value) => normalizeString(value))
    .filter(Boolean);

  if (parts.length < 3) {
    return [];
  }

  return parts
    .slice(1)
    .filter((value, index, all) => all.indexOf(value) === index)
    .sort();
}

export function readConversationParticipants(
  data: Record<string, unknown>,
  options: { conversationId?: string } = {},
): string[] {
  const canonicalParticipants = readConversationParticipantIdsFromCanonicalId(
    String(options.conversationId ?? ""),
  );

  if (canonicalParticipants.length > 0) {
    return canonicalParticipants;
  }

  const participants = new Set<string>();

  const addValue = (value: unknown): void => {
    const normalized = String(value ?? "").trim();
    if (normalized.length > 0) {
      participants.add(normalized);
    }
  };

  const addArray = (value: unknown): void => {
    if (!Array.isArray(value)) {
      return;
    }

    for (const item of value) {
      addValue(item);
    }
  };

  const addMapKeys = (value: unknown): void => {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      return;
    }

    for (const key of Object.keys(value as Record<string, unknown>)) {
      addValue(key);
    }
  };

  const source = data || {};

  for (const field of [
    "participantIds",
    "participant_ids",
    "participants",
    "userIds",
    "user_ids",
    "memberIds",
    "member_ids",
    "users",
  ]) {
    addArray(source[field]);
  }

  for (const field of [
    "participantNames",
    "participant_names",
    "unreadCount",
    "unread_count",
    "lastReadAt",
    "last_read_at",
    "archivedBy",
    "archived_by",
    "blockedBy",
    "blocked_by",
    "participantsMap",
    "participants_map",
  ]) {
    addMapKeys(source[field]);
  }

  const conversationId = String(options.conversationId ?? "").trim();

  if (conversationId.startsWith("offer_") && conversationId.includes("__")) {
    const pieces = conversationId
      .split("__")
      .map((piece) => piece.trim())
      .filter((piece) => piece.length > 0);

    if (pieces.length >= 3) {
      addValue(pieces[pieces.length - 2]);
      addValue(pieces[pieces.length - 1]);
    }
  }

  return Array.from(participants).sort();
}

export function buildConversationParticipantFields(participants: string[]): {
  participants: string[];
  participant_ids: string[];
  participantIds: string[];
  userIds: string[];
  memberIds: string[];
} {
  const normalized = participants
    .map((value) => String(value || "").trim())
    .filter(Boolean)
    .filter((value, index, all) => all.indexOf(value) === index);

  return {
    participants: normalized,
    participantIds: normalized,
    participant_ids: normalized,
    userIds: normalized,
    memberIds: normalized,
  };
}