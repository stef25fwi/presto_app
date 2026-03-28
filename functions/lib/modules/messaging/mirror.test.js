"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const mirror_1 = require("./mirror");
(0, node_test_1.default)("buildConversationMirrorFields writes critical camelCase and snake_case aliases", () => {
    const fields = (0, mirror_1.buildConversationMirrorFields)({
        participants: ["buyer_a", "seller_b"],
        participantNames: {
            buyer_a: "Alice",
            seller_b: "Bruno",
        },
        otherUserName: "Bruno",
        offerId: "offer_123",
        offerTitle: "Peinture salon",
        lastMessage: "Bonjour",
        lastSenderId: "buyer_a",
        lastSenderName: "Alice",
        unreadCount: {
            buyer_a: 0,
            seller_b: 1,
        },
        messageCount: 2,
        status: "open",
        archivedBy: {},
        blockedBy: {},
    });
    strict_1.default.deepEqual(fields.participants, ["buyer_a", "seller_b"]);
    strict_1.default.deepEqual(fields.participant_ids, ["buyer_a", "seller_b"]);
    strict_1.default.deepEqual(fields.participantIds, ["buyer_a", "seller_b"]);
    strict_1.default.deepEqual(fields.participantNames, { buyer_a: "Alice", seller_b: "Bruno" });
    strict_1.default.deepEqual(fields.participant_names, { buyer_a: "Alice", seller_b: "Bruno" });
    strict_1.default.equal(fields.offerId, "offer_123");
    strict_1.default.equal(fields.offer_id, "offer_123");
    strict_1.default.equal(fields.lastMessage, "Bonjour");
    strict_1.default.equal(fields.last_message, "Bonjour");
    strict_1.default.deepEqual(fields.unreadCount, { buyer_a: 0, seller_b: 1 });
    strict_1.default.deepEqual(fields.unread_count, { buyer_a: 0, seller_b: 1 });
    strict_1.default.equal(fields.messageCount, 2);
    strict_1.default.equal(fields.message_count, 2);
});
(0, node_test_1.default)("readConversationMirrorData tolerates legacy snake_case only payloads", () => {
    const mirror = (0, mirror_1.readConversationMirrorData)({
        participant_ids: ["buyer_a", "seller_b"],
        participant_names: {
            buyer_a: "Alice",
            seller_b: "Bruno",
        },
        other_user_name: "Bruno",
        offer_id: "offer_123",
        offer_title: "Peinture salon",
        last_message: "Bonjour",
        last_sender_id: "seller_b",
        last_sender_name: "Bruno",
        unread_count: {
            buyer_a: 1,
            seller_b: 0,
        },
        message_count: 4,
        status: "open",
    });
    strict_1.default.deepEqual(mirror.participants, ["buyer_a", "seller_b"]);
    strict_1.default.deepEqual(mirror.participantNames, { buyer_a: "Alice", seller_b: "Bruno" });
    strict_1.default.equal(mirror.otherUserName, "Bruno");
    strict_1.default.equal(mirror.offerId, "offer_123");
    strict_1.default.equal(mirror.offerTitle, "Peinture salon");
    strict_1.default.equal(mirror.lastMessage, "Bonjour");
    strict_1.default.equal(mirror.lastSenderId, "seller_b");
    strict_1.default.equal(mirror.lastSenderName, "Bruno");
    strict_1.default.deepEqual(mirror.unreadCount, { buyer_a: 1, seller_b: 0 });
    strict_1.default.equal(mirror.messageCount, 4);
});
(0, node_test_1.default)("readConversationMessageCount falls back to mirrored last message aliases", () => {
    strict_1.default.equal((0, mirror_1.readConversationMessageCount)({ last_message: "Salut" }), 1);
    strict_1.default.equal((0, mirror_1.readConversationMessageCount)({ last_message: "   " }), 0);
});
//# sourceMappingURL=mirror.test.js.map