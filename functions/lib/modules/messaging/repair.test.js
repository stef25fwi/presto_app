"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const repair_1 = require("./repair");
(0, node_test_1.default)("parseCanonicalConversationId reads offer and participants from canonical ids", () => {
    strict_1.default.deepEqual((0, repair_1.parseCanonicalConversationId)("offer_offer_123__buyer_a__seller_b"), {
        offerId: "offer_123",
        participantIds: ["buyer_a", "seller_b"],
    });
});
(0, node_test_1.default)("mergeUniqueParticipantIds deduplicates and sorts participant ids", () => {
    strict_1.default.deepEqual((0, repair_1.mergeUniqueParticipantIds)(["seller_b", "buyer_a"], ["buyer_a", "", "seller_b"], ["helper_c"]), ["buyer_a", "helper_c", "seller_b"]);
});
(0, node_test_1.default)("normalizeParticipantBooleanMap fills missing participants with false", () => {
    strict_1.default.deepEqual((0, repair_1.normalizeParticipantBooleanMap)(["buyer_a", "seller_b"], { seller_b: true }), { buyer_a: false, seller_b: true });
});
(0, node_test_1.default)("normalizeParticipantNumberMap fills missing participants with zero", () => {
    strict_1.default.deepEqual((0, repair_1.normalizeParticipantNumberMap)(["buyer_a", "seller_b"], { seller_b: 2 }), { buyer_a: 0, seller_b: 2 });
});
(0, node_test_1.default)("normalizeParticipantUnknownMap keeps only participant scoped keys", () => {
    strict_1.default.deepEqual((0, repair_1.normalizeParticipantUnknownMap)(["buyer_a"], {
        buyer_a: "2026-04-03T10:00:00.000Z",
        seller_b: "2026-04-03T11:00:00.000Z",
    }), { buyer_a: "2026-04-03T10:00:00.000Z" });
});
//# sourceMappingURL=repair.test.js.map