"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CONVERSATION_PARTICIPANT_MAP_ALIASES = exports.CONVERSATION_PARTICIPANT_FIELD_ALIASES = exports.CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES = void 0;
exports.readConversationParticipants = readConversationParticipants;
exports.buildConversationParticipantFields = buildConversationParticipantFields;
exports.CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES = [
    "participants",
    "participant_ids",
    "participantIds",
];
exports.CONVERSATION_PARTICIPANT_FIELD_ALIASES = [
    ...exports.CONVERSATION_PARTICIPANT_QUERY_FIELD_ALIASES,
    "userIds",
    "memberIds",
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
function readConversationParticipants(data) {
    const result = [];
    const seen = new Set();
    const appendParticipant = (value) => {
        const normalized = String(value ?? "").trim();
        if (!normalized || seen.has(normalized))
            return;
        seen.add(normalized);
        result.push(normalized);
    };
    for (const field of exports.CONVERSATION_PARTICIPANT_FIELD_ALIASES) {
        const raw = data[field];
        if (!Array.isArray(raw))
            continue;
        for (const value of raw) {
            appendParticipant(value);
        }
    }
    for (const field of exports.CONVERSATION_PARTICIPANT_MAP_ALIASES) {
        const raw = data[field];
        if (!raw || typeof raw !== "object")
            continue;
        for (const key of Object.keys(raw)) {
            appendParticipant(key);
        }
    }
    result.sort();
    return result;
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
    };
}
//# sourceMappingURL=participants.js.map