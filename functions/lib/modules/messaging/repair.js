"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseCanonicalConversationId = parseCanonicalConversationId;
exports.mergeUniqueParticipantIds = mergeUniqueParticipantIds;
exports.normalizeParticipantBooleanMap = normalizeParticipantBooleanMap;
exports.normalizeParticipantNumberMap = normalizeParticipantNumberMap;
exports.normalizeParticipantUnknownMap = normalizeParticipantUnknownMap;
function normalizeString(value) {
    return String(value ?? "").trim();
}
function parseCanonicalConversationId(conversationId) {
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
function mergeUniqueParticipantIds(...participantGroups) {
    const seen = new Set();
    const result = [];
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
function normalizeParticipantBooleanMap(participants, input) {
    const result = {};
    for (const participantId of participants) {
        const normalizedParticipantId = normalizeString(participantId);
        if (!normalizedParticipantId)
            continue;
        result[normalizedParticipantId] = input[normalizedParticipantId] === true;
    }
    return result;
}
function normalizeParticipantNumberMap(participants, input) {
    const result = {};
    for (const participantId of participants) {
        const normalizedParticipantId = normalizeString(participantId);
        if (!normalizedParticipantId)
            continue;
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
function normalizeParticipantUnknownMap(participants, input) {
    const result = {};
    for (const participantId of participants) {
        const normalizedParticipantId = normalizeString(participantId);
        if (!normalizedParticipantId)
            continue;
        if (Object.prototype.hasOwnProperty.call(input, normalizedParticipantId)) {
            result[normalizedParticipantId] = input[normalizedParticipantId];
        }
    }
    return result;
}
//# sourceMappingURL=repair.js.map