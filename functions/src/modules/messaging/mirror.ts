import { readConversationParticipants } from "./participants";

type UnknownRecord = Record<string, unknown>;
type BooleanMap = Record<string, boolean>;
type NumberLikeMap = Record<string, unknown>;
type StringMap = Record<string, string>;

export interface ConversationMirrorData {
  participants: string[];
  participantNames: StringMap;
  otherUserName: string;
  listingId: string;
  listingTitle: string;
  offerId: string;
  offerTitle: string;
  lastMessage: string;
  lastSenderId: string;
  lastSenderName: string;
  unreadCount: NumberLikeMap;
  messageCount: number;
  createdAt?: unknown;
  updatedAt?: unknown;
  lastMessageAt?: unknown;
  lastReadAt: UnknownRecord;
  status: string;
  archivedBy: BooleanMap;
  blockedBy: BooleanMap;
}

export interface ConversationMirrorFieldsInput {
  participants?: string[];
  participantNames?: StringMap;
  otherUserName?: string;
  listingId?: string;
  listingTitle?: string;
  offerId?: string;
  offerTitle?: string;
  lastMessage?: string;
  lastSenderId?: string;
  lastSenderName?: string;
  unreadCount?: NumberLikeMap;
  messageCount?: unknown;
  createdAt?: unknown;
  updatedAt?: unknown;
  lastMessageAt?: unknown;
  lastReadAt?: UnknownRecord;
  status?: string;
  archivedBy?: BooleanMap;
  blockedBy?: BooleanMap;
}

function pickFirstValue(data: UnknownRecord, keys: string[]): unknown {
  for (const key of keys) {
    if (!Object.prototype.hasOwnProperty.call(data, key)) continue;
    const value = data[key];
    if (value !== undefined && value !== null) return value;
  }
  return undefined;
}

function normalizeString(value: unknown): string {
  return String(value ?? "").trim();
}

function normalizeParticipants(values: unknown[]): string[] {
  return values
    .map((value) => normalizeString(value))
    .filter(Boolean)
    .filter((value, index, all) => all.indexOf(value) === index)
    .sort();
}

function normalizeBooleanMap(map: Record<string, unknown>): BooleanMap {
  const result: BooleanMap = {};
  for (const [key, value] of Object.entries(map)) {
    const normalizedKey = normalizeString(key);
    if (!normalizedKey) continue;
    result[normalizedKey] = value === true;
  }
  return result;
}

function readStringMap(data: UnknownRecord, keys: string[]): StringMap {
  const raw = pickFirstValue(data, keys);
  if (!raw || typeof raw !== "object") return {};

  const result: StringMap = {};
  for (const [key, value] of Object.entries(raw as UnknownRecord)) {
    const normalizedKey = normalizeString(key);
    const normalizedValue = normalizeString(value);
    if (!normalizedKey || !normalizedValue) continue;
    result[normalizedKey] = normalizedValue;
  }
  return result;
}

function readUnknownMap(data: UnknownRecord, keys: string[]): UnknownRecord {
  const raw = pickFirstValue(data, keys);
  if (!raw || typeof raw !== "object") return {};

  const result: UnknownRecord = {};
  for (const [key, value] of Object.entries(raw as UnknownRecord)) {
    const normalizedKey = normalizeString(key);
    if (!normalizedKey) continue;
    result[normalizedKey] = value;
  }
  return result;
}

function readBooleanMap(data: UnknownRecord, keys: string[]): BooleanMap {
  const raw = pickFirstValue(data, keys);
  if (!raw || typeof raw !== "object") return {};

  const result: BooleanMap = {};
  for (const [key, value] of Object.entries(raw as UnknownRecord)) {
    const normalizedKey = normalizeString(key);
    if (!normalizedKey) continue;
    result[normalizedKey] = value === true;
  }
  return result;
}

function sanitizeMapKeys<T>(map: Record<string, T>): Record<string, T> {
  const result: Record<string, T> = {};
  for (const [key, value] of Object.entries(map)) {
    const normalizedKey = normalizeString(key);
    if (!normalizedKey) continue;
    result[normalizedKey] = value;
  }
  return result;
}

function buildParticipantUniverse(input: ConversationMirrorFieldsInput): string[] {
  return normalizeParticipants([
    ...(input.participants ?? []),
    ...Object.keys(input.participantNames ?? {}),
    ...Object.keys(input.unreadCount ?? {}),
    ...Object.keys(input.lastReadAt ?? {}),
    ...Object.keys(input.archivedBy ?? {}),
    ...Object.keys(input.blockedBy ?? {}),
  ]);
}

function resolveParticipantsForWrite(input: ConversationMirrorFieldsInput): string[] {
  const explicitParticipants = normalizeParticipants(input.participants ?? []);
  if (explicitParticipants.length > 0) {
    return explicitParticipants;
  }

  return buildParticipantUniverse(input);
}

function scopeStringMapToParticipants(
  map: StringMap,
  participants: string[],
): StringMap {
  if (participants.length === 0) {
    return sanitizeMapKeys(map);
  }

  const normalizedMap = sanitizeMapKeys(map);
  const result: StringMap = {};

  for (const participantId of participants) {
    const value = normalizeString(normalizedMap[participantId]);
    if (!value) continue;
    result[participantId] = value;
  }

  return result;
}

function scopeUnknownMapToParticipants(
  map: UnknownRecord,
  participants: string[],
): UnknownRecord {
  if (participants.length === 0) {
    return sanitizeMapKeys(map);
  }

  const normalizedMap = sanitizeMapKeys(map);
  const result: UnknownRecord = {};

  for (const participantId of participants) {
    if (!Object.prototype.hasOwnProperty.call(normalizedMap, participantId)) {
      continue;
    }
    result[participantId] = normalizedMap[participantId];
  }

  return result;
}

function buildUnreadCountMap(
  map: UnknownRecord,
  participants: string[],
): UnknownRecord {
  if (participants.length === 0) {
    return sanitizeMapKeys(map);
  }

  const normalizedMap = sanitizeMapKeys(map);
  const result: UnknownRecord = {};

  for (const participantId of participants) {
    if (Object.prototype.hasOwnProperty.call(normalizedMap, participantId)) {
      result[participantId] = normalizedMap[participantId];
      continue;
    }
    result[participantId] = 0;
  }

  return result;
}

function buildBooleanMapForParticipants(
  map: Record<string, unknown>,
  participants: string[],
): BooleanMap {
  const normalizedMap = normalizeBooleanMap(map);
  if (participants.length === 0) {
    return normalizedMap;
  }

  const result: BooleanMap = {};
  for (const participantId of participants) {
    result[participantId] = normalizedMap[participantId] === true;
  }
  return result;
}

export function readConversationMessageCount(data: UnknownRecord): number {
  const rawCount = pickFirstValue(data, ["messageCount", "message_count"]);
  if (typeof rawCount === "number" && Number.isFinite(rawCount) && rawCount >= 0) {
    return Math.floor(rawCount);
  }

  const lastMessage = normalizeString(pickFirstValue(data, ["lastMessage", "last_message"]));
  return lastMessage ? 1 : 0;
}

export function readConversationMirrorData(
  data: UnknownRecord,
  options: {
    conversationId?: string;
  } = {},
): ConversationMirrorData {
  return {
    participants: readConversationParticipants(data, {
      conversationId: options.conversationId,
    }),
    participantNames: readStringMap(data, ["participantNames", "participant_names"]),
    otherUserName: normalizeString(pickFirstValue(data, ["otherUserName", "other_user_name"])),
    listingId: normalizeString(pickFirstValue(data, ["listingId", "offerId", "offer_id"])),
    listingTitle: normalizeString(pickFirstValue(data, ["listingTitle", "offerTitle", "offer_title"])),
    offerId: normalizeString(pickFirstValue(data, ["offerId", "offer_id"])),
    offerTitle: normalizeString(pickFirstValue(data, ["offerTitle", "offer_title"])),
    lastMessage: normalizeString(pickFirstValue(data, ["lastMessage", "last_message"])),
    lastSenderId: normalizeString(pickFirstValue(data, ["lastSenderId", "last_sender_id"])),
    lastSenderName: normalizeString(pickFirstValue(data, ["lastSenderName", "last_sender_name"])),
    unreadCount: readUnknownMap(data, ["unreadCount", "unread_count"]),
    messageCount: readConversationMessageCount(data),
    createdAt: pickFirstValue(data, ["createdAt", "created_at"]),
    updatedAt: pickFirstValue(data, ["updatedAt", "updated_at"]),
    lastMessageAt: pickFirstValue(data, ["lastMessageAt", "last_message_at"]),
    lastReadAt: readUnknownMap(data, ["lastReadAt", "last_read_at"]),
    status: normalizeString(pickFirstValue(data, ["status"])),
    archivedBy: readBooleanMap(data, ["archivedBy"]),
    blockedBy: readBooleanMap(data, ["blockedBy"]),
  };
}

export function buildConversationMirrorFields(
  input: ConversationMirrorFieldsInput,
): Record<string, unknown> {
  const participants = resolveParticipantsForWrite(input);
  const participantNames = scopeStringMapToParticipants(
    input.participantNames ?? {},
    participants,
  );
  const unreadCount = buildUnreadCountMap(input.unreadCount ?? {}, participants);
  const lastReadAt = scopeUnknownMapToParticipants(input.lastReadAt ?? {}, participants);
  const archivedBy = buildBooleanMapForParticipants(input.archivedBy ?? {}, participants);
  const blockedBy = buildBooleanMapForParticipants(input.blockedBy ?? {}, participants);

  const fields: Record<string, unknown> = {
    participants,
    participant_ids: participants,
    participantIds: participants,
    userIds: participants,
    memberIds: participants,
    participantNames,
    participant_names: participantNames,
    unreadCount,
    unread_count: unreadCount,
    lastReadAt,
    last_read_at: lastReadAt,
    archivedBy,
    blockedBy,
  };

  if (input.otherUserName !== undefined) {
    const value = normalizeString(input.otherUserName);
    fields.otherUserName = value;
    fields.other_user_name = value;
  }

  if (input.listingId !== undefined) {
    const value = normalizeString(input.listingId);
    fields.listingId = value;
    fields.offerId = value;
    fields.offer_id = value;
  }

  if (input.offerId !== undefined) {
    const value = normalizeString(input.offerId);
    fields.offerId = value;
    fields.offer_id = value;
  }

  if (input.listingTitle !== undefined) {
    const value = normalizeString(input.listingTitle);
    fields.listingTitle = value;
    fields.offerTitle = value;
    fields.offer_title = value;
  }

  if (input.offerTitle !== undefined) {
    const value = normalizeString(input.offerTitle);
    fields.offerTitle = value;
    fields.offer_title = value;
  }

  if (input.lastMessage !== undefined) {
    const value = normalizeString(input.lastMessage);
    fields.lastMessage = value;
    fields.last_message = value;
  }

  if (input.lastSenderId !== undefined) {
    const value = normalizeString(input.lastSenderId);
    fields.lastSenderId = value;
    fields.last_sender_id = value;
  }

  if (input.lastSenderName !== undefined) {
    const value = normalizeString(input.lastSenderName);
    fields.lastSenderName = value;
    fields.last_sender_name = value;
  }

  if (input.messageCount !== undefined) {
    fields.messageCount = input.messageCount;
    fields.message_count = input.messageCount;
  }

  if (input.createdAt !== undefined) {
    fields.createdAt = input.createdAt;
    fields.created_at = input.createdAt;
  }

  if (input.updatedAt !== undefined) {
    fields.updatedAt = input.updatedAt;
    fields.updated_at = input.updatedAt;
  }

  if (input.lastMessageAt !== undefined) {
    fields.lastMessageAt = input.lastMessageAt;
    fields.last_message_at = input.lastMessageAt;
  }

  if (input.status !== undefined) {
    fields.status = normalizeString(input.status);
  }

  return fields;
}