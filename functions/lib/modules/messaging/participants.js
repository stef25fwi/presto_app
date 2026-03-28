"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.readConversationParticipants = readConversationParticipants;
exports.buildConversationParticipantFields = buildConversationParticipantFields;
function readConversationParticipants(data) {
    const result = [];
    const seen = new Set();
    for (const field of ["participants", "participant_ids"]) {
        const raw = data[field];
        if (!Array.isArray(raw))
            continue;
        for (const value of raw) {
            const participantId = String(value || "").trim();
            if (!participantId || seen.has(participantId))
                continue;
            seen.add(participantId);
            result.push(participantId);
        }
    }
    return result;
}
function buildConversationParticipantFields(participants) {
    const normalized = participants
        .map((value) => String(value || "").trim())
        .filter(Boolean)
        .filter((value, index, all) => all.indexOf(value) === index);
    return {
        participants: normalized,
        participant_ids: normalized,
    };
}
//# sourceMappingURL=participants.js.map