"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.readConversationMessageCount = readConversationMessageCount;
exports.readConversationMirrorData = readConversationMirrorData;
exports.buildConversationMirrorFields = buildConversationMirrorFields;
const participants_1 = require("./participants");
function pickFirstValue(data, keys) {
    for (const key of keys) {
        if (!Object.prototype.hasOwnProperty.call(data, key))
            continue;
        const value = data[key];
        if (value !== undefined && value !== null)
            return value;
    }
    return undefined;
}
function normalizeString(value) {
    return String(value ?? "").trim();
}
function normalizeParticipants(values) {
    return values
        .map((value) => normalizeString(value))
        .filter(Boolean)
        .filter((value, index, all) => all.indexOf(value) === index)
        .sort();
}
function readStringMap(data, keys) {
    const raw = pickFirstValue(data, keys);
    if (!raw || typeof raw !== "object")
        return {};
    const result = {};
    for (const [key, value] of Object.entries(raw)) {
        const normalizedKey = normalizeString(key);
        const normalizedValue = normalizeString(value);
        if (!normalizedKey || !normalizedValue)
            continue;
        result[normalizedKey] = normalizedValue;
    }
    return result;
}
function readUnknownMap(data, keys) {
    const raw = pickFirstValue(data, keys);
    if (!raw || typeof raw !== "object")
        return {};
    const result = {};
    for (const [key, value] of Object.entries(raw)) {
        const normalizedKey = normalizeString(key);
        if (!normalizedKey)
            continue;
        result[normalizedKey] = value;
    }
    return result;
}
function readBooleanMap(data, keys) {
    const raw = pickFirstValue(data, keys);
    if (!raw || typeof raw !== "object")
        return {};
    const result = {};
    for (const [key, value] of Object.entries(raw)) {
        const normalizedKey = normalizeString(key);
        if (!normalizedKey)
            continue;
        result[normalizedKey] = value === true;
    }
    return result;
}
function sanitizeMapKeys(map) {
    const result = {};
    for (const [key, value] of Object.entries(map)) {
        const normalizedKey = normalizeString(key);
        if (!normalizedKey)
            continue;
        result[normalizedKey] = value;
    }
    return result;
}
function buildParticipantUniverse(input) {
    return normalizeParticipants([
        ...(input.participants ?? []),
        ...Object.keys(input.participantNames ?? {}),
        ...Object.keys(input.unreadCount ?? {}),
        ...Object.keys(input.lastReadAt ?? {}),
        ...Object.keys(input.archivedBy ?? {}),
        ...Object.keys(input.blockedBy ?? {}),
    ]);
}
function readConversationMessageCount(data) {
    const rawCount = pickFirstValue(data, ["messageCount", "message_count"]);
    if (typeof rawCount === "number" && Number.isFinite(rawCount) && rawCount >= 0) {
        return Math.floor(rawCount);
    }
    const lastMessage = normalizeString(pickFirstValue(data, ["lastMessage", "last_message"]));
    return lastMessage ? 1 : 0;
}
function readConversationMirrorData(data) {
    return {
        participants: (0, participants_1.readConversationParticipants)(data),
        participantNames: readStringMap(data, ["participantNames", "participant_names"]),
        otherUserName: normalizeString(pickFirstValue(data, ["otherUserName", "other_user_name"])),
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
function buildConversationMirrorFields(input) {
    const participants = buildParticipantUniverse(input);
    const participantNames = sanitizeMapKeys(input.participantNames ?? {});
    const unreadCount = sanitizeMapKeys(input.unreadCount ?? {});
    const lastReadAt = sanitizeMapKeys(input.lastReadAt ?? {});
    const archivedBy = sanitizeMapKeys(input.archivedBy ?? {});
    const blockedBy = sanitizeMapKeys(input.blockedBy ?? {});
    const fields = {
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
    if (input.offerId !== undefined) {
        const value = normalizeString(input.offerId);
        fields.offerId = value;
        fields.offer_id = value;
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
//# sourceMappingURL=mirror.js.map