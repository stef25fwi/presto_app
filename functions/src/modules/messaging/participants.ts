export const CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES = [
  "participantIds",
  "participants",
  "participant_ids",
  "userIds",
  "users",
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
  options: {
    conversationId?: string;
  } = {},
): string[] {
  const canonicalParticipants = readConversationParticipantIdsFromCanonicalId(
    options.conversationId ?? "",
  );

  // Les conversations 1:1 suivent l'ID canonique offer_<offerId>__<uidA>__<uidB>.
  // Quand cet ID est présent, il est la source de vérité pour la visibilité.
  if (canonicalParticipants.length >= 2) {
    return canonicalParticipants;
  }

  const result: string[] = [];
  const seen = new Set<string>();

  const appendParticipant = (value: unknown): void => {
    const normalized = normalizeString(value);
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