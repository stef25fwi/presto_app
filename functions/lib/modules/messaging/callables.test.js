"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const https_1 = require("firebase-functions/v2/https");
const callables_1 = require("./callables");
const mirror_1 = require("./mirror");
(0, node_test_1.default)("readConversationMessageCount uses atomic counter when present", () => {
    strict_1.default.equal((0, mirror_1.readConversationMessageCount)({ messageCount: 3, lastMessage: "" }), 3);
});
(0, node_test_1.default)("readConversationMessageCount falls back to lastMessage for legacy conversations", () => {
    strict_1.default.equal((0, mirror_1.readConversationMessageCount)({ lastMessage: "Bonjour" }), 1);
    strict_1.default.equal((0, mirror_1.readConversationMessageCount)({ lastMessage: "   " }), 0);
});
(0, node_test_1.default)("mergeConversationParticipants preserves legacy ids and injects required participants", () => {
    strict_1.default.deepEqual((0, callables_1.mergeConversationParticipants)(["buyer_a"], ["seller_b", "buyer_a"]), ["buyer_a", "seller_b"]);
});
(0, node_test_1.default)("computeUnreadCountAfterMessageDeletion decrements only unread recipients", () => {
    strict_1.default.deepEqual((0, callables_1.computeUnreadCountAfterMessageDeletion)({
        participants: ["buyer_a", "seller_b"],
        unreadCount: { buyer_a: 0, seller_b: 2 },
        lastReadAt: {},
        deletedSenderId: "buyer_a",
        deletedCreatedAt: new Date("2026-03-28T10:00:00.000Z"),
    }), { buyer_a: 0, seller_b: 1 });
});
(0, node_test_1.default)("resolveOfferLikeData prefers listings when both sources exist", () => {
    const result = (0, callables_1.resolveOfferLikeData)({
        offerData: { ownerId: "owner_offer", title: "Offre legacy" },
        listingData: { ownerId: "owner_listing", title: "Listing marketplace" },
    });
    strict_1.default.equal(result.source, "listings");
    strict_1.default.equal(result.data.ownerId, "owner_listing");
});
(0, node_test_1.default)("resolveOfferLikeData falls back to listings when offer is absent", () => {
    const result = (0, callables_1.resolveOfferLikeData)({
        offerData: null,
        listingData: { ownerId: "owner_listing", title: "Listing marketplace" },
    });
    strict_1.default.equal(result.source, "listings");
    strict_1.default.equal(result.data.ownerId, "owner_listing");
});
(0, node_test_1.default)("resolveOfferLikeData throws not-found when neither source exists", () => {
    strict_1.default.throws(() => (0, callables_1.resolveOfferLikeData)({ offerData: null, listingData: null }), (error) => {
        strict_1.default.ok(error instanceof https_1.HttpsError);
        strict_1.default.equal(error.code, "not-found");
        return true;
    });
});
//# sourceMappingURL=callables.test.js.map