"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const participants_1 = require("./participants");
(0, node_test_1.default)("readConversationParticipants merges current and legacy participant fields", () => {
    const participants = (0, participants_1.readConversationParticipants)({
        participants: ["user_a", "user_b", ""],
        participant_ids: ["user_b", "user_c", null],
    });
    strict_1.default.deepEqual(participants, ["user_a", "user_b", "user_c"]);
});
(0, node_test_1.default)("buildConversationParticipantFields writes both participant fields", () => {
    const fields = (0, participants_1.buildConversationParticipantFields)(["user_b", "user_a", "user_b"]);
    strict_1.default.deepEqual(fields, {
        participants: ["user_b", "user_a"],
        participant_ids: ["user_b", "user_a"],
    });
});
//# sourceMappingURL=participants.test.js.map