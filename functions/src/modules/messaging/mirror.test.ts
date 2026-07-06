import assert from "node:assert/strict";
import test from "node:test";
import {
  buildConversationMirrorFields,
  readConversationMessageCount,
  readConversationMirrorData,
} from "./mirror";

test("buildConversationMirrorFields writes critical camelCase and snake_case aliases", () => {
  const fields = buildConversationMirrorFields({
    participants: ["buyer_a", "seller_b"],
    participantNames: {
      buyer_a: "Alice",
      seller_b: "Bruno",
    },
    otherUserName: "Bruno",
    listingId: "listing_123",
    listingTitle: "Peinture salon",
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

  assert.deepEqual(fields.participantIds, ["buyer_a", "seller_b"]);
  // Les alias redondants ne sont plus écrits (champ canonique unique).
  assert.equal(fields.participants, undefined);
  assert.equal(fields.participant_ids, undefined);
  assert.equal(fields.userIds, undefined);
  assert.equal(fields.memberIds, undefined);
  assert.deepEqual(fields.participantNames, { buyer_a: "Alice", seller_b: "Bruno" });
  assert.deepEqual(fields.participant_names, { buyer_a: "Alice", seller_b: "Bruno" });
  assert.equal(fields.listingId, "listing_123");
  assert.equal(fields.offerId, "offer_123");
  assert.equal(fields.offer_id, "offer_123");
  assert.equal(fields.listingTitle, "Peinture salon");
  assert.equal(fields.lastMessage, "Bonjour");
  assert.equal(fields.last_message, "Bonjour");
  assert.deepEqual(fields.unreadCount, { buyer_a: 0, seller_b: 1 });
  assert.deepEqual(fields.unread_count, { buyer_a: 0, seller_b: 1 });
  assert.equal(fields.messageCount, 2);
  assert.equal(fields.message_count, 2);
});

test("readConversationMirrorData tolerates legacy snake_case only payloads", () => {
  const mirror = readConversationMirrorData({
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

  assert.deepEqual(mirror.participants, ["buyer_a", "seller_b"]);
  assert.deepEqual(mirror.participantNames, { buyer_a: "Alice", seller_b: "Bruno" });
  assert.equal(mirror.otherUserName, "Bruno");
  assert.equal(mirror.offerId, "offer_123");
  assert.equal(mirror.offerTitle, "Peinture salon");
  assert.equal(mirror.lastMessage, "Bonjour");
  assert.equal(mirror.lastSenderId, "seller_b");
  assert.equal(mirror.lastSenderName, "Bruno");
  assert.deepEqual(mirror.unreadCount, { buyer_a: 1, seller_b: 0 });
  assert.equal(mirror.messageCount, 4);
});

test("readConversationMirrorData prefers canonical listing fields when available", () => {
  const mirror = readConversationMirrorData({
    participantIds: ["buyer_a", "seller_b"],
    listingId: "listing_123",
    listingTitle: "Cuisine a monter",
    offerId: "offer_legacy_123",
    offerTitle: "Offre legacy",
  });

  assert.equal(mirror.listingId, "listing_123");
  assert.equal(mirror.listingTitle, "Cuisine a monter");
  assert.equal(mirror.offerId, "offer_legacy_123");
  assert.equal(mirror.offerTitle, "Offre legacy");
});

test("readConversationMessageCount falls back to mirrored last message aliases", () => {
  assert.equal(readConversationMessageCount({ last_message: "Salut" }), 1);
  assert.equal(readConversationMessageCount({ last_message: "   " }), 0);
});

test("buildConversationMirrorFields scopes participant maps to normalized participants", () => {
  const fields = buildConversationMirrorFields({
    participants: ["buyer_a", "seller_b"],
    participantNames: {
      buyer_a: "Alice",
      seller_b: "Bruno",
      ghost_user: "Ghost",
    },
    unreadCount: {
      buyer_a: 0,
      seller_b: 2,
      ghost_user: 99,
    },
    archivedBy: {
      seller_b: true,
      ghost_user: true,
    },
    deletedBy: {
      buyer_a: true,
      ghost_user: true,
    },
    blockedBy: {
      ghost_user: true,
    },
    lastReadAt: {
      seller_b: "2026-01-01T00:00:00.000Z",
      ghost_user: "2026-01-01T00:00:00.000Z",
    },
  });

  assert.deepEqual(fields.participantIds, ["buyer_a", "seller_b"]);
  assert.deepEqual(fields.participantNames, { buyer_a: "Alice", seller_b: "Bruno" });
  assert.deepEqual(fields.unreadCount, { buyer_a: 0, seller_b: 2 });
  assert.deepEqual(fields.archivedBy, { buyer_a: false, seller_b: true });
  assert.deepEqual(fields.deletedBy, { buyer_a: true, seller_b: false });
  assert.deepEqual(fields.blockedBy, { buyer_a: false, seller_b: false });
  assert.deepEqual(fields.lastReadAt, { seller_b: "2026-01-01T00:00:00.000Z" });
});

test("readConversationMirrorData can recover participants from canonical id", () => {
  const mirror = readConversationMirrorData(
    {
      unreadCount: {
        b: 0,
      },
    },
    {
      conversationId: "offer_offer123__seller_b__buyer_a",
    },
  );

  assert.deepEqual(mirror.participants, ["buyer_a", "seller_b"]);
});