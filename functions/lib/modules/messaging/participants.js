"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CONVERSATION_PARTICIPANT_MAP_ALIASES = exports.CONVERSATION_PARTICIPANT_FIELD_ALIASES = exports.CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES = void 0;
exports.readConversationParticipantIdsFromCanonicalId = readConversationParticipantIdsFromCanonicalId;
exports.readConversationParticipants = readConversationParticipants;
exports.buildConversationParticipantFields = buildConversationParticipantFields;
exports.CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES = [
    "participantIds",
    "participants",
    "participant_ids",
    "userIds",
    "memberIds",
];
exports.CONVERSATION_PARTICIPANT_FIELD_ALIASES = [
    ...exports.CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES,
];
exports.CONVERSATION_PARTICIPANT_MAP_ALIASES = [
    "participantNames",
    "participant_names",
    "unreadCount",
    "unread_count",
    "lastReadAt",
    "last_read_at",
    "archivedBy",
    "blockedBy",
];
function normalizeString(value) {
    return String(value ?? "").trim();
}
function readConversationParticipantIdsFromCanonicalId(conversationId) {
    const normalizedConversationId = normalizeString(conversationId);
    if (!normalizedConversationId.startsWith("offer_")) {
        return [];
    }
    const parts = normalizedConversationId
        .slice("offer_".length)
        .split("__")
        .map((value) => normalizeString(value))
        .filter(Boolean);
    // Accept 2-part IDs: offer_listingId__uid (only the uid is the participant).
    // Accept 3+-part IDs: offer_listingId__uid1__uid2 (standard format).
    if (parts.length < 2) {
        return [];
    }
    return parts
        .slice(1)
        .filter((value, index, all) => all.indexOf(value) === index)
        .sort();
}
function readConversationParticipants(data, options = {}) {
    const canonicalParticipants = readConversationParticipantIdsFromCanonicalId(String(options.conversationId ?? ""));
    if (canonicalParticipants.length > 0) {
        return canonicalParticipants;
    }
    const participants = new Set();
    const addValue = (value) => {
        const normalized = String(value ?? "").trim();
        if (normalized.length > 0) {
            participants.add(normalized);
        }
    };
    const addArray = (value) => {
        if (!Array.isArray(value)) {
            return;
        }
        for (const item of value) {
            addValue(item);
        }
    };
    const addMapKeys = (value) => {
        if (!value || typeof value !== "object" || Array.isArray(value)) {
            return;
        }
        for (const key of Object.keys(value)) {
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
        const raw = source[field];
        if (Array.isArray(raw)) {
            addArray(raw);
        }
        else if (raw && typeof raw === "object" && !Array.isArray(raw)) {
            // Older conversations may store participants as a map { uid: true }.
            addMapKeys(raw);
        }
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
        "deletedBy",
        "deleted_by",
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
function buildConversationParticipantFields(participants) {
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
//# sourceMappingURL=participants.js.map