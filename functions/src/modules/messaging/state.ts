export type ConversationStatus = "open" | "archived" | "closed";

export function readConversationFlagMap(
  data: Record<string, unknown>,
  field: "archivedBy" | "blockedBy",
): Record<string, boolean> {
  const raw = data[field];
  if (!raw || typeof raw != "object") return {};

  const result: Record<string, boolean> = {};
  for (const [key, value] of Object.entries(raw as Record<string, unknown>)) {
    result[key] = value === true;
  }
  return result;
}

export function isConversationFlagEnabledForUser(
  data: Record<string, unknown>,
  field: "archivedBy" | "blockedBy",
  userId: string,
): boolean {
  return readConversationFlagMap(data, field)[userId] === true;
}

export function isConversationBlocked(data: Record<string, unknown>): boolean {
  const blockedBy = readConversationFlagMap(data, "blockedBy");
  return Object.values(blockedBy).some((value) => value === true);
}

export function computeConversationStatus(
  participants: string[],
  archivedBy: Record<string, boolean>,
  blockedBy: Record<string, boolean>,
): ConversationStatus {
  if (Object.values(blockedBy).some((value) => value === true)) {
    return "closed";
  }

  if (participants.length > 0 && participants.every((participantId) => archivedBy[participantId] === true)) {
    return "archived";
  }

  return "open";
}