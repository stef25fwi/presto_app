type UnknownRecord = Record<string, unknown>;

function normalizeString(value: unknown): string {
  return String(value ?? "").trim();
}

export function parseCanonicalConversationId(conversationId: string): {
  offerId: string;
  participantIds: string[];
} {
  const normalizedConversationId = normalizeString(conversationId);
  if (!normalizedConversationId.startsWith("offer_")) {
    return {
      offerId: "",
      participantIds: [],
    };
  }

  const parts = normalizedConversationId
    .slice("offer_".length)
    .split("__")
    .map((value) => normalizeString(value))
    .filter(Boolean);

  if (parts.length < 3) {
    return {
      offerId: "",
      participantIds: [],
    };
  }

  return {
    offerId: parts[0] ?? "",
    participantIds: parts.slice(1),
  };
}

export function mergeUniqueParticipantIds(...participantGroups: string[][]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];

  for (const participantGroup of participantGroups) {
    for (const participantId of participantGroup) {
      const normalizedParticipantId = normalizeString(participantId);
      if (!normalizedParticipantId || seen.has(normalizedParticipantId)) {
        continue;
      }
      seen.add(normalizedParticipantId);
      result.push(normalizedParticipantId);
    }
  }

  result.sort();
  return result;
}

export function normalizeParticipantBooleanMap(
  participants: string[],
  input: Record<string, boolean>,
): Record<string, boolean> {
  const result: Record<string, boolean> = {};

  for (const participantId of participants) {
    const normalizedParticipantId = normalizeString(participantId);
    if (!normalizedParticipantId) continue;
    result[normalizedParticipantId] = input[normalizedParticipantId] === true;
  }

  return result;
}

export function normalizeParticipantNumberMap(
  participants: string[],
  input: UnknownRecord,
): Record<string, number> {
  const result: Record<string, number> = {};

  for (const participantId of participants) {
    const normalizedParticipantId = normalizeString(participantId);
    if (!normalizedParticipantId) continue;

    const rawValue = input[normalizedParticipantId];
    const numericValue = typeof rawValue === "number"
      ? rawValue
      : Number.parseInt(String(rawValue ?? ""), 10);
    result[normalizedParticipantId] = Number.isFinite(numericValue)
      ? Math.max(0, Math.floor(numericValue))
      : 0;
  }

  return result;
}

export function normalizeParticipantUnknownMap(
  participants: string[],
  input: UnknownRecord,
): UnknownRecord {
  const result: UnknownRecord = {};

  for (const participantId of participants) {
    const normalizedParticipantId = normalizeString(participantId);
    if (!normalizedParticipantId) continue;

    if (Object.prototype.hasOwnProperty.call(input, normalizedParticipantId)) {
      result[normalizedParticipantId] = input[normalizedParticipantId];
    }
  }

  return result;
}
