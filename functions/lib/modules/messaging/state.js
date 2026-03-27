"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.readConversationFlagMap = readConversationFlagMap;
exports.isConversationFlagEnabledForUser = isConversationFlagEnabledForUser;
exports.isConversationBlocked = isConversationBlocked;
exports.computeConversationStatus = computeConversationStatus;
function readConversationFlagMap(data, field) {
    const raw = data[field];
    if (!raw || typeof raw != "object")
        return {};
    const result = {};
    for (const [key, value] of Object.entries(raw)) {
        result[key] = value === true;
    }
    return result;
}
function isConversationFlagEnabledForUser(data, field, userId) {
    return readConversationFlagMap(data, field)[userId] === true;
}
function isConversationBlocked(data) {
    const blockedBy = readConversationFlagMap(data, "blockedBy");
    return Object.values(blockedBy).some((value) => value === true);
}
function computeConversationStatus(participants, archivedBy, blockedBy) {
    if (Object.values(blockedBy).some((value) => value === true)) {
        return "closed";
    }
    if (participants.length > 0 && participants.every((participantId) => archivedBy[participantId] === true)) {
        return "archived";
    }
    return "open";
}
//# sourceMappingURL=state.js.map